using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace FhirLoader
{
    public class BundleFileHandler : BaseFileHandler
    {
        private readonly string _filePath;
        private readonly ILogger<BundleFileHandler> _logger;
        private readonly int _bundleSize;

        public BundleFileHandler(string filePath, int bundleSize, ILogger<BundleFileHandler> logger) : base(filePath, logger)
        {
            _filePath = filePath;
            _bundleSize = bundleSize;
            _logger = logger;
        }

        public override IEnumerable<(string bundle, int count)> ConvertToBundles()
        {
            JObject bundle;

            // We must read the full file to resolve any refs
            string bundleContent = File.ReadAllText(_filePath);
            bundle = JObject.Parse(bundleContent);

            try
            {
                SyntheaReferenceResolver.ConvertUUIDs(bundle);
            }
            catch
            {
                _logger.LogError($"Failed to resolve references in input file {_filePath}.");
                throw;
            }

            var bundleResources = bundle.SelectTokens("$.entry[*].resource");
            if (bundleResources.Count() <= _bundleSize)
            {
                yield return (bundle.ToString(Formatting.Indented), bundleResources.Count());
            }
            
            while (true)
            {
                var resourceChunk = bundleResources.Take(_bundleSize);
                bundleResources = bundleResources.Skip(_bundleSize);

                if (resourceChunk.Count() == 0)
                    break;

                var newBundle = JObject.FromObject(new
                {
                    resourceType = "Bundle",
                    type = "batch",
                    entry =
                    from r in resourceChunk
                    select new
                    {
                        resource = r,
                        request = new
                        {
                            method = r.SelectToken("id") is not null ? "PUT" : "POST",
                            url = r.SelectToken("id") is not null ? $"{r["resourceType"]}/{r["id"]}" : r["resourceType"]
                        }
                    }
                });

                yield return (newBundle.ToString(Formatting.Indented), resourceChunk.Count());
            }
        }
    }
}
