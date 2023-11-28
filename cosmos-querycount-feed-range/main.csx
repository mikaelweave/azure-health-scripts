#!/usr/bin/env dotnet-script
#r "nuget: DotNetEnv, 2.5.0"
#r "nuget: Microsoft.Azure.Cosmos, 3.36.0"

using DotNetEnv;
using Microsoft.Azure.Cosmos;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

class CosmosDBCounter
{
    private CosmosClient cosmosClient;
    private Container container;

    static CosmosDBCounter()
    {
        // Load environment variables from .env file
        Env.Load();
    }

    public CosmosDBCounter()
    {
        string connectionString = Environment.GetEnvironmentVariable("COSMOS_CONNECTION_STRING");
        string databaseId = Environment.GetEnvironmentVariable("DATABASE_ID");
        string containerId = Environment.GetEnvironmentVariable("CONTAINER_ID");

        cosmosClient = new CosmosClient(connectionString);
        container = cosmosClient.GetContainer(databaseId, containerId);
    }

    public async Task<Dictionary<string, int>> GetRowCountPerFeedRangeAsync(string queryString)
    {
        var feedRanges = await container.GetFeedRangesAsync();
        var countsPerRange = new Dictionary<string, int>();

        foreach (var feedRange in feedRanges)
        {
            var queryDefinition = new QueryDefinition(queryString);
            
            // var queryRequestOptions = new QueryRequestOptions { PartitionKey = new PartitionKey(feedRange.ToString()) };
            // var iterator = container.GetItemQueryIterator<int>(queryDefinition, requestOptions: queryRequestOptions);

            var iterator = container.GetItemQueryIterator<int>(feedRange, queryDefinition);

            var count = 0;
            while (iterator.HasMoreResults)
            {
                var response = await iterator.ReadNextAsync();
                count += response.Sum();
            }

            countsPerRange.Add(feedRange.ToString(), count);
        }

        return countsPerRange;
    }
}

// Usage
var cosmosDbCounter = new CosmosDBCounter();
var counts = await cosmosDbCounter.GetRowCountPerFeedRangeAsync("SELECT VALUE COUNT(1) FROM c WHERE c.resourceTypeName = 'CarePlan' AND c.isSystem = false AND c.isDeleted = false AND c.isHistory = false");
int i = 0;
foreach (var count in counts)
{
    i++;
    Console.WriteLine($"FeedRange #{i}: {count.Key}, Count: {count.Value}");
}

Console.WriteLine("Total is " + counts.Values.Sum().ToString("N0"));