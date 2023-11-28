#!/usr/bin/env dotnet-script
#r "nuget: Hl7.Fhir.R4, 5.3.0"
#r "nuget: Azure.Storage.Blobs, 12.10.0"

using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Hl7.Fhir.Model;
using Hl7.Fhir.Serialization;

string connectionString = "DefaultEndpointsProtocol=https;AccountName=***REMOVED***;AccountKey=***REMOVED***;EndpointSuffix=core.windows.net";
string containerName = "import1";
int maxBlobsToImport = 10000;
BlobContainerClient container = new BlobContainerClient(connectionString, containerName);

Console.WriteLine($"Fetching blobs from {container.Uri.AbsoluteUri}");

List<List<Parameters.ParameterComponent>> importItems = new();
await foreach (var blobItem in container.GetBlobsAsync())
{
    if (importItems.Count >= maxBlobsToImport) break;
    importItems.Add(new(){
                new() { Name = "type", Value = new FhirString(blobItem.Name.Split('/').Last().Split('.').First()) },
                new() { Name = "url", Value = new FhirString($"{container.Uri.AbsoluteUri}/{blobItem.Name}") },
    });
}

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