#!/usr/bin/env dotnet-script
#r "nuget: Azure.Core, 1.30.0"
#r "nuget: Azure.Identity, 1.8.2"
#r "nuget: Azure.ResourceManager, 1.4.0"
#r "nuget: Azure.ResourceManager.Resources, 1.4.0"
#r "nuget: Azure.ResourceManager.HealthcareApis, 1.0.1"

using System;
using Azure.Core;
using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.Resources;
using Azure.ResourceManager.HealthcareApis;

const string SUBSCRIPTION_ID = "17af5f40-c564-4afe-ada0-fe7193bd474a";
const string RESOURCE_GROUP_NAME = "applied-team-shared";
const string WORKSPACE_NAME = "applied";
const string FHIR_NAME = "synthea-100k-uscore";

TokenCredential credential = new DefaultAzureCredential();
ArmClient client = new ArmClient(credential);

public FhirServiceResource GetFhirService(ArmClient client, string subscriptionId, string resourceGroupName, string workspaceName, string fhirServiceName)
{
    ResourceIdentifier fhirServiceResourceId = FhirServiceResource.CreateResourceIdentifier(SUBSCRIPTION_ID, RESOURCE_GROUP_NAME, WORKSPACE_NAME, FHIR_NAME);

    FhirServiceResource fhir = client.GetFhirServiceResource(fhirServiceResourceId);

    return fhir;
}

Console.WriteLine("Done!");