# Toggle `$import`

This template will allow you to toggle the `[$import operation](https://docs.microsoft.com/en-us/azure/healthcare-apis/fhir/import-data)` on a FHIR service inside a Azure Health Data Services workspace. 

## Deployment via portal

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.storage%2Fstorage-account-create%2Fazuredeploy.json)

## Deployment via azure cli

You can deploy the Bicep template directly with this azure cli command.

```sh
az deployment group create \
    --name main \
    --resource-group "rg-name" \
    --template-file "toggle_import.bicep" \
    --parameters workspaceName="ahds-workspace-name" \
    --parameters fhirName="fhir-service-name" \
    --parameters storageName="storage-account-name" \
    --parameters containerName="blob-container-name" \
    --parameters toggleImport=true
```
