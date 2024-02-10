using Azure.Storage.Blobs;
using Hl7.Fhir.Model;
using Hl7.Fhir.Serialization;

using Task = System.Threading.Tasks.Task;

string connectionString = Environment.GetCommandLineArgs()[1];
string containerName = Environment.GetCommandLineArgs()[2];
int blobToSkip = int.Parse(Environment.GetCommandLineArgs()[3]);
int maxBlobsToImport = int.Parse(Environment.GetCommandLineArgs()[4]);

int maxLines = -1; // Approx max number of resources to $import
int currentLines = 0;
BlobContainerClient container = new BlobContainerClient(connectionString, containerName);

Console.WriteLine($"Fetching blobs from {container.Uri.AbsoluteUri}");

List<Task<List<Parameters.ParameterComponent>?>> tasks = new();
SemaphoreSlim maxDegreeOfParallelism = new SemaphoreSlim(32); // Limit the number of concurrent tasks
object lockObject = new();
CancellationTokenSource cancellationTokenSource = new();
CancellationToken cancellationToken = cancellationTokenSource.Token;

await foreach (var blobItem in container.GetBlobsAsync(cancellationToken: cancellationToken))
{
    if (blobToSkip-- > 0) continue;
    if (tasks.Count >= maxBlobsToImport) break;

    await maxDegreeOfParallelism.WaitAsync();
    tasks.Add(Task.Run(async () =>
    {
        try
        {
            if (maxLines > 0)
            {
                int localLineCount = 0;
                if (currentLines >= maxLines)
                {
                    Console.WriteLine($"Max lines reached. Skipping {blobItem.Name}");
                    cancellationTokenSource.Cancel();
                    return null;
                }

                Console.WriteLine($"Counting lines in {blobItem.Name}. Current line count: {currentLines}. Max lines: {maxLines}.");
            
                BlobClient blobClient = container.GetBlobClient(blobItem.Name);
                await using (var stream = await blobClient.OpenReadAsync(cancellationToken: cancellationToken))
                using (var reader = new StreamReader(stream))
                {
                    while (reader.ReadLine() != null)
                    {
                        cancellationToken.ThrowIfCancellationRequested();
                        localLineCount++;
                    }
                }

                lock (lockObject)
                {
                    currentLines += localLineCount;
                }
            }
            if (blobItem.Name.EndsWith(".ndjson"))
            {
                // Return the processed item
                return new List<Parameters.ParameterComponent> 
                {
                    new() { Name = "type", Value = new FhirString(blobItem.Name.Split('/').Last().Split('.').First().Split('-').First()) },
                    new() { Name = "url", Value = new FhirString($"{container.Uri.AbsoluteUri}/{blobItem.Name}") },
                };
            }
            return null;
        }
        catch (OperationCanceledException)
        {
            Console.WriteLine($"Task cancelled while processing {blobItem.Name}");
            return null;
        }
        finally
        {
            maxDegreeOfParallelism.Release();
        }
    }, cancellationToken));
}

// Wait for all tasks to complete
var results = await System.Threading.Tasks.Task.WhenAll(tasks);
List<List<Parameters.ParameterComponent>> importItems = results.ToList().Where(x => x != null).Select(x => x!).ToList();

Console.WriteLine($"Creating $import request.");

// Create FHIR import request
if (importItems.Count > 0)
{
    Parameters parameters = new();
    parameters.Parameter.Add(new Parameters.ParameterComponent
    {
        Name = "inputFormat",
        Value = new FhirString("application/fhir+ndjson")
    });
    parameters.Parameter.Add(new Parameters.ParameterComponent
    {
        Name = "mode",
        Value = new FhirString("IncrementalLoad")
    });

    foreach (var paramList in importItems)
    {
        parameters.Parameter.Add(new Parameters.ParameterComponent
        {
            Name = "input",
            Part = paramList,
        }); 
    }

    // Serialize Parameters to JSON
    var serializer = new FhirJsonSerializer();
    var json = serializer.SerializeToString(parameters);

    Console.WriteLine(json);
}