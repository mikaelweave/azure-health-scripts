#!/usr/bin/env dotnet-script

#r "nuget: Hl7.Fhir.R4, 5.3.0"

using Hl7.Fhir.Model;
using Hl7.Fhir.Serialization;

int bundleCount = 500;

// Creating the first bundle
var createBundle = new Bundle
{
    Type = Bundle.BundleType.Transaction
};

for (int i = 1; i <= bundleCount; i++)
{
    var patient = new Patient
    {
        Identifier = new List<Identifier>
        {
            new Identifier { Value = $"Patient{i}" }
        }
    };

    createBundle.Entry.Add(new Bundle.EntryComponent
    {
        FullUrl = "urn:uuid:" + Guid.NewGuid(),
        Resource = patient,
        Request = new Bundle.RequestComponent
        {
            Method = Bundle.HTTPVerb.POST,
            Url = "Patient"
        }
    });
}

// Serialize the create bundle
string serializedCreateBundle = new FhirJsonSerializer(new SerializerSettings { Pretty = true }).SerializeToString(createBundle);

Console.WriteLine("Serialized create bundle:");
Console.WriteLine("-------------------------\n\n\n");
Console.WriteLine(serializedCreateBundle);
Console.WriteLine("-------------------------\n\n\n");

// Creating the second bundle for conditional updates
var updateBundle = new Bundle
{
    Type = Bundle.BundleType.Transaction
};

for (int i = 1; i <= bundleCount; i++)
{
    var patient = new Patient
    {
        Active = true
    };

    updateBundle.Entry.Add(new Bundle.EntryComponent
    {
        Resource = patient,
        Request = new Bundle.RequestComponent
        {
            Method = Bundle.HTTPVerb.PUT,
            Url = $"Patient?identifier=Patient{i}"
        }
    });
}

// Serialize the update bundle
string serializedUpdateBundle = new FhirJsonSerializer(new SerializerSettings { Pretty = true }).SerializeToString(updateBundle);
Console.WriteLine("Serialized conditionalUpdate bundle:");
Console.WriteLine("-------------------------\n\n\n");
Console.WriteLine(serializedUpdateBundle);
Console.WriteLine("-------------------------\n\n\n");