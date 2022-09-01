
@minLength(2)
@maxLength(6)
@description('Prefex for your resources. It must be 2-6 characters and only be letters.')
param resourcePrefix string = 'fhapim'

@description('Location for your resources.')
param resourceLocation string = resourceGroup().location

@description('Informs template to deploy or use existing FHIR/Azure Health Data Services workspace')
param useExistingFhirService bool = false

@description('If using existing FHIR Service, what is the name of the Azure Health Data Services workspace')
param existingAzureHealthDataServicesWorkspace string = ''
@description('If using existing FHIR Service, what is the name of the FHIR Service?')
param existingFhirService string = ''

var resourceTags = {
  'AHDS-Sample': 'FHIR-APIM-Starter'
}

var uniqueNameString = uniqueString(guid(resourceGroup().id), resourceLocation)

var ahdsWorkspaceName = useExistingFhirService ? existingAzureHealthDataServicesWorkspace : '${resourcePrefix}${uniqueNameString}0ahds'
var fhirName = useExistingFhirService ? existingFhirService : 'apim-test'
var fhirUrl = 'https://${ahdsWorkspaceName}-${fhirName}.fhir.azurehealthcareapis.com'

@description('Deploys Azuer Health Data Services and FHIR Service')
module fhir_template 'fhir.bicep'= {
  name: 'ahds-with-fhir-${ahdsWorkspaceName}'
  params: {
    deployOrReference: useExistingFhirService ? 'reference' : 'deploy'
    workspaceName: ahdsWorkspaceName
    fhirServiceName: fhirName
    tenantId: subscription().tenantId
    location: resourceLocation
    tags: resourceTags
  }
}

var datalakeName = '${resourcePrefix}${uniqueNameString}0lake'
@description('Deploys an Azure Data Lake Gen 2 for data pipeline')
module datalake_template 'datalake.bicep'= {
  name: 'datalake-${datalakeName}'
  params: {
    name: datalakeName
    location: resourceLocation
    tags: resourceTags
  }
}

var name = '${resourcePrefix}${uniqueNameString}'

@description('Deploys FHIR to Analytics function.')
module analytics_sync_app_template 'analytics_sync_app.bicep'= {
  name: 'fhirtoanalyticsfunction-${name}'
  params: {
    name: name
    location: resourceLocation
    fhirServiceUrl: fhirUrl
    storageAccountName: datalakeName
    tags: resourceTags
  }

  dependsOn: [databricks_template, datalake_template]
}

@description('Setup identity connection between FHIR and the function app')
module functionFhirIdentity './fhirIdentity.bicep'= {
  name: 'fhirIdentity-function'
  params: {
    fhirId: fhir_template.outputs.fhirId
    principalId: analytics_sync_app_template.outputs.functionAppPrincipalId
  }
}
