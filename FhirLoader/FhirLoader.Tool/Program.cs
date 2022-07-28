using CommandLine;
using Azure.Identity;
using Azure.Core;
using CommandLine.Text;
using Microsoft.Extensions.Logging;
using Microsoft.Identity.Client;
using System.Threading.Tasks.Dataflow;
using System.Diagnostics.Metrics;

namespace FhirLoader.Tool
{
    public class Program
    {
        private static ILogger<Program> _logger = ApplicationLogging.CreateLogger<Program>();
        private static List<IDisposable> cleanupList = new List<IDisposable> { ApplicationLogging.LogFactory };

        private const int BUNDLE_SIZE = 300;

        static async Task Main(string[] args)
        {
            var result = await Parser.Default.ParseArguments<Options>(args).WithParsedAsync(Run);
        }

        static async Task Run(Options opt)
        {
            try
            {
                var files = LoadInputFiles(opt.LocalPath);
                var bundles = files.SelectMany(x => x.ConvertToBundles());

                // Configure HttpClient with BaseUrl and Access Token
                var client = new HttpClient();
                await ConfigureHttpClient(client, opt.FhirUrl);

                // Create a bundle sender
                var sender = new BundleSender(client, ApplicationLogging.CreateLogger<BundleSender>());
                Metrics.Instance.Start();

                var actionBlock = new ActionBlock<(string bundle, int count)>(async bundleWrapper =>
                {
                    await sender.SendIt(bundleWrapper.bundle, bundleWrapper.count);
                },
                    new ExecutionDataflowBlockOptions { MaxDegreeOfParallelism = 20 }
                );

                // For each file, send segmented bundles
                foreach (var file in files)
                    foreach (var bundle in file.ConvertToBundles())
                        actionBlock.Post(bundle);

                actionBlock.Complete();
                actionBlock.Completion.Wait();
            }
            catch (DirectoryNotFoundException)
            {
                _logger.LogError($"Could not find path {opt.LocalPath}");
                cleanupList.ForEach(x => x.Dispose());
                Metrics.Instance.Stop();
                Environment.Exit(1);
                return;
            }
            catch (CredentialUnavailableException)
            {
                _logger.LogError($"Could not obtain Azure credential. Please use `az login` or another method specified here: https://docs.microsoft.com/dotnet/api/azure.identity.defaultazurecredential?view=azure-dotnet");
                cleanupList.ForEach(x => x.Dispose());
                Metrics.Instance.Stop();
                Environment.Exit(1);
                return;
            }
        }

        static IEnumerable<BaseFileHandler> LoadInputFiles(string bundlePath)
        {
            var bundleFileLogger = ApplicationLogging.CreateLogger<BundleFileHandler>();
            var bulkFileLogger = ApplicationLogging.CreateLogger<BulkFileHandler>();

            var inputBundles = Directory
                .EnumerateFiles(bundlePath, "*", SearchOption.AllDirectories)
                .Where(s => s.EndsWith(".json"));
            var inputBulkfiles = Directory
                .EnumerateFiles(bundlePath, "*", SearchOption.AllDirectories)
                .Where(s => s.EndsWith(".ndjson"));

            _logger.LogInformation($"Found {inputBundles.Count()} FHIR bundles and {inputBulkfiles.Count()} FHIR bulk data files.");
            
            foreach (var filePath in inputBundles.Concat(inputBulkfiles).OrderBy(x => x))
            {
                if (filePath.EndsWith(".json"))
                {
                    yield return new BundleFileHandler(filePath, BUNDLE_SIZE, bundleFileLogger);
                }
                else if (filePath.EndsWith(".ndjson"))
                {
                    yield return new BulkFileHandler(filePath, BUNDLE_SIZE, bulkFileLogger);
                }
            }
        }

        static async Task<HttpClient> ConfigureHttpClient(HttpClient client, string baseUrl)
        {
            client.BaseAddress = new Uri(baseUrl);

            var accessToken = await FetchToken(baseUrl);

            client.DefaultRequestHeaders.Clear();
            client.DefaultRequestHeaders.Accept.Clear();
            client.DefaultRequestHeaders.Add("Authorization", $"Bearer {accessToken.Token}");

            return client;
        }

        static async Task<AccessToken> FetchToken(string fhirUrl)
        {
            string[] scopes = new string[] { $"{fhirUrl}/.default" };
            TokenRequestContext tokenRequestContext = new(scopes);
            var credential = await new DefaultAzureCredential(true).GetTokenAsync(tokenRequestContext);

            _logger.LogInformation($"Got token for FHIR server {fhirUrl}.");
            return credential;
        }
    }
}