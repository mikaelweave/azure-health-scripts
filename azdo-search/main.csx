#!/usr/bin/env dotnet-script

#r "nuget: Newtonsoft.Json, 13.0.3"

using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading.Tasks;
using Newtonsoft.Json.Linq;

class AzureDevOpsClient
{
    private readonly string _personalAccessToken;
    private readonly string _organization;
    private readonly string _project;

    public AzureDevOpsClient(string personalAccessToken, string organization, string project)
    {
        _personalAccessToken = personalAccessToken;
        _organization = organization;
        _project = project;
    }

    public async Task SearchStringInTaskGroups(string searchString)
    {
        using (var client = new HttpClient())
        {
            client.DefaultRequestHeaders.Accept.Add(
                new MediaTypeWithQualityHeaderValue("application/json"));

            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Basic",
                Convert.ToBase64String(System.Text.Encoding.ASCII.GetBytes($":{_personalAccessToken}")));

            var response = await client.GetAsync(
                $"https://dev.azure.com/{_organization}/{_project}/_apis/distributedtask/taskgroups?api-version=6.0-preview.1");

            if (response.IsSuccessStatusCode)
            {
                var result = await response.Content.ReadAsStringAsync();
                JArray taskGroups = JArray.Parse(JObject.Parse(result)["value"].ToString());

                foreach (var taskGroup in taskGroups)
                {
                    if (taskGroup.ToString().Contains(searchString))
                    {
                        Console.WriteLine($"Found '{searchString}' in task group: {taskGroup["name"]}");
                    }
                }
            }
            else
            {
                Console.WriteLine("Error: " + response.ReasonPhrase);
            }
        }
    }
}

var devOpsClient = new AzureDevOpsClient("xxx", "org", "project");
await devOpsClient.SearchStringInTaskGroups("xxx");