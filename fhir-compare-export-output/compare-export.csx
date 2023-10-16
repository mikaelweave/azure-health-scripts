#!/usr/bin/env dotnet-script

using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Linq;

public class OutputItem
{
    [JsonPropertyName("type")]
    public string Type { get; set; }

    [JsonPropertyName("count")]
    public int Count { get; set; }
}

public class ExportData
{
    [JsonPropertyName("output")]
    public List<OutputItem> Output { get; set; }
}

string[] fileNames = { "export1.json", "export2.json" };


foreach (string fileName in fileNames)
{
    int totalCount = 0;
    Dictionary<string, int> countByResourceType = new Dictionary<string, int>();
    Console.WriteLine("Processing file: " + fileName);

    string jsonContent = File.ReadAllText(fileName);

    ExportData exportData = JsonSerializer.Deserialize<ExportData>(jsonContent);

    if (exportData != null && exportData.Output != null)
    {
        foreach (var item in exportData.Output)
        {
            string resourceType = item.Type;
            int count = item.Count;

            totalCount += count;

            if (countByResourceType.ContainsKey(resourceType))
            {
                countByResourceType[resourceType] += count;
            }
            else
            {
                countByResourceType[resourceType] = count;
            }
        }
    }

    Console.WriteLine("Total Count: " + totalCount);
    Console.WriteLine("Count by ResourceType:");
    foreach (var kvp in countByResourceType)
    {
        Console.WriteLine($"{kvp.Key}: {kvp.Value}");
    }
    Console.WriteLine("--------------------");
}

