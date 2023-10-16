#!/usr/bin/env dotnet-script
#r "nuget: Hl7.Fhir.R4, 5.3.0"

using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using Hl7.Fhir.Model;
using Hl7.Fhir.Serialization;

public class ExportOutputItem
{
    [JsonPropertyName("type")]
    public string Type { get; set; }

    [JsonPropertyName("count")]
    public int Count { get; set; }

    [JsonPropertyName("url")]
    public string Url { get; set; }
}

public class ExportData
{
    [JsonPropertyName("output")]
    public List<ExportOutputItem> Output { get; set; }
}

public class ImportOutputItem
{
    [JsonPropertyName("type")]
    public string Type { get; set; }

    [JsonPropertyName("url")]
    public string Url { get; set; }
}

string fileName = "export1.json";
string jsonContent = File.ReadAllText(fileName);

ExportData exportData = JsonSerializer.Deserialize<ExportData>(jsonContent);

if (exportData != null)
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

    foreach (var exOut in exportData.Output)
    {
        parameters.Parameter.Add(new Parameters.ParameterComponent
        {
            Name = "input",
            Part = new List<Parameters.ParameterComponent>()
            {
                new Parameters.ParameterComponent
                {
                    Name = "type",
                    Value = new FhirString(exOut.Type)
                },
                new Parameters.ParameterComponent
                {
                    Name = "url",
                    Value = new FhirString(exOut.Url)
                }
            }
        }); 
    }

    // Serialize Parameters to JSON
    var serializer = new FhirJsonSerializer();
    var json = serializer.SerializeToString(parameters);

    Console.WriteLine(json);
}