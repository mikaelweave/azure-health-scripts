@description('Name of the FHIR service Web App.')
@minLength(3)
@maxLength(24)
param serviceName string

@description('Default location for resources.')
param location string = resourceGroup().location

@allowed([
  'F1'
  'D1'
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1'
  'P2'
  'P3'
  'P4'
  'P2V2'
  'P3v2'
  'P3V3'
])
param appServicePlanSku string = 'P2V2'

@description('Sets the number of instances to deploy for the app service.')
param numberOfInstances int = 1

@description('OAuth Authority')
param securityAuthenticationAuthority string = ''

@description('Audience (aud) to validate in JWT')
param securityAuthenticationAudience string = ''

@description('Deploy Application Insights for the FHIR server.')
param deployApplicationInsights bool = true

@allowed([
  'southeastasia'
  'northeurope'
  'westeurope'
  'eastus'
  'southcentralus'
  'westus2'
  'usgovvirginia'
  'usgovarizona'
])
param applicationInsightsLocation string = 'westus2'

@description('Additional configuration properties for the FHIR server. In the form {"path1":"value1","path2":"value2"}')
param additionalFhirServerConfigProperties object = {}

@allowed([
  'CosmosDb'
  'SqlServer'
])
@description('Which data store to use for the FHIR server.')
param solutionType string = 'SqlServer'

@description('An object representing the default consistency policy for the Cosmos DB account. See https://docs.microsoft.com/azure/templates/microsoft.documentdb/databaseaccounts#ConsistencyPolicy')
param cosmosDefaultConsistency string = 'Strong'

@description('Key url for the Cosmos DB customer managed key. If not provided a system managed key will be used. If an invalid value is provided the service will not start.')
param cosmosDbCmkUrl string = ''

@description('Name of Sql Server (existing or new). If empty, a name will be generated.')
param sqlServerName string = ''

@allowed([
  'new'
  'existing'
])
@description('Determines whether or not a new SqlServer should be provisioned.')
param sqlServerNewOrExisting string = 'new'

@description('The password for the sql admin user if using SQL server.')
@secure()
param sqlAdminPassword string = ''

@description('Determine whether the sql schema should be automatically upgraded on server startup. If set to \'tool\', sql schema will not be initialized or upgraded on the server startup. The schema migration tool will be required to perform initialize or upgrade. If set to \'auto\', sql schema will be upgraded to the maximum supported version.')
@allowed([
  'auto'
  'tool'
])
param sqlSchemaAutomaticUpdatesEnabled string = 'auto'

@description('Version of the FHIR specification to deploy.')
@allowed([
  'Stu3'
  'R4'
  'R4B'
  'R5'
])
param fhirVersion string = 'R4'

@description('Tag of the docker image to deploy.')
param imageTag string = '20231101.2'

@description('Determines whether export will be enabled for this fhir instance. If true, a storage account will be created as part of the deployment. You will need owner or user-administrator permissions for this.')
param enableExport bool = false

@description('Determines whether the $convert-data operation will be enabled for this fhir instance. If true, an Azure container registry will be created as part of the deployment. You will need owner or user-administrator permissions for this.')
param enableConvertData bool = false

@description('Determines whether the $reindex operation will be enabled for this fhir instance.')
param enableReindex bool = false

@description('Determines whether the $import operation will be enabled for this fhir instance.')
param enableImport bool = false

@description('Supports parallel background task running')
param backgroundTaskCount int = 2

@description('Number of app service instances to deploy. Useful for perf testing.')
param appServiceCount int = 1

var serviceNameClean = toLower(serviceName)
var keyvaultEndpoint = 'https://${serviceNameClean}${environment().suffixes.keyvaultDns}/'
var storageAccountName = '${substring(replace(serviceNameClean, '-', ''), 0, min(11, length(replace(serviceNameClean, '-', ''))))}${uniqueString(resourceGroup().id, serviceNameClean)}'
var securityAuthenticationEnabled = ((!empty(securityAuthenticationAuthority)) && (!empty(securityAuthenticationAudience)))
var azureContainerRegistryName = '${substring(replace(serviceNameClean, '-', ''), 0, min(11, length(replace(serviceNameClean, '-', ''))))}${uniqueString(resourceGroup().id, serviceNameClean)}'
var enableIntegrationStore = enableExport || enableImport
var staticFhirServerConfigProperties = {
  APPINSIGHTS_PORTALINFO: 'ASP.NETCORE'
  APPINSIGHTS_PROFILERFEATURE_VERSION: '1.0.0'
  APPINSIGHTS_SNAPSHOTFEATURE_VERSION: '1.0.0'
  WEBSITE_NODE_DEFAULT_VERSION: '6.9.4'
  KeyVault__Endpoint: keyvaultEndpoint
  FhirServer__Security__Enabled: securityAuthenticationEnabled
  FhirServer__Security__EnableAadSmartOnFhirProxy: false
  FhirServer__Security__Authentication__Authority: securityAuthenticationAuthority
  FhirServer__Security__Authentication__Audience: securityAuthenticationAudience
  CosmosDb__ContinuationTokenSizeLimitInKb: '1'
  SqlServer__Initialize: true
  SqlServer__SchemaOptions__AutomaticUpdatesEnabled: ((sqlSchemaAutomaticUpdatesEnabled == 'auto') ? true : false)
  DataStore: solutionType
  TaskHosting__Enabled: true
  TaskHosting__MaxRunningTaskCount: backgroundTaskCount
  FhirServer__Operations__IntegrationDataStore__StorageAccountUri: (enableImport ? 'https://${storageAccountName}.blob${environment().suffixes.storage}' : 'null')
  FhirServer__Operations__Export__Enabled: enableExport
  FhirServer__Operations__Export__StorageAccountUri: (enableExport ? 'https://${storageAccountName}.blob${environment().suffixes.storage}' : 'null')
  FhirServer__Operations__ConvertData__Enabled: enableConvertData
  FhirServer__Operations__ConvertData__ContainerRegistryServers__0: (enableConvertData ? '${azureContainerRegistryName}${environment().suffixes.acrLoginServer}' : 'null')
  FhirServer__Operations__Reindex__Enabled: enableReindex
  FhirServer__Operations__Import__Enabled: enableImport
}
var combinedFhirServerConfigProperties = union(staticFhirServerConfigProperties, additionalFhirServerConfigProperties)
var tags = {
  FhirServerSolution: solutionType
}

var appNameSuffixes = [for i in range(0, appServiceCount): appServiceCount == 1 && i == 0 ? '' : i]

module appServices './appService.bicep' = [for appNameSuffix in appNameSuffixes: {
  name: '${serviceNameClean}-appService${appNameSuffix}'
  params: {
    location: location
    appServicePlanName: '${serviceNameClean}-asp${appNameSuffix}'
    appServiceName: '${serviceNameClean}${appNameSuffix}'
    appServicePlanSku: appServicePlanSku
    numberOfInstances: numberOfInstances
    deployApplicationInsights: deployApplicationInsights
    applicationInsightsLocation: applicationInsightsLocation
    combinedFhirServerConfigProperties: combinedFhirServerConfigProperties
    fhirVersion: fhirVersion
    imageTag: imageTag
    resourceTags: tags
    appInsightsName: 'AppInsights-${serviceNameClean}'
  }
}]

module sql './sql.bicep' = if (solutionType == 'SqlServer') {
  name: '${serviceNameClean}-sql'
  params: {
    location: location
    sqlServerName: (empty(sqlServerName) ? serviceNameClean : sqlServerName)
    sqlServerNewOrExisting: sqlServerNewOrExisting
    sqlAdminPassword: sqlAdminPassword
    sqlDatabaseName: 'FHIR${fhirVersion}'
    resourceTags: tags
    vaultName: keyVault.name
  }
}

module cosmos './cosmos.bicep' = if (solutionType == 'CosmosDb') {
  name: '${serviceNameClean}-cosmos'
  params: {
    location: location
    cosmosDefaultConsistency: cosmosDefaultConsistency
    cosmosDbCmkUrl: cosmosDbCmkUrl
    cosmosDbAccountName: serviceNameClean
    resourceTags: tags
    vaultName: keyVault.name
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2015-06-01' = {
  name: serviceNameClean
  location: location
  tags: {
    FhirServerSolution: solutionType
  }
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    accessPolicies: [for i in range(0, appServiceCount): {
      tenantId: tenant().tenantId
      objectId: appServices[i].outputs.appServicePrincipalId
      permissions: {
        secrets: [
          'get'
          'list'
          'set'
        ]
      }
    }]
    enabledForDeployment: false
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = if (enableIntegrationStore) {
  name: storageAccountName
  location: location
  properties: {
    supportsHttpsTrafficOnly: true
  }
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
  tags: {}
  dependsOn: []
}

@description('This is the built-in Storage Blob Data Contributor. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor')
resource storageBlobDataContributerRoleId 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

resource storageBlobContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for i in range(0, appServiceCount): if (enableIntegrationStore) {
  name: guid(subscription().id, '${serviceNameClean}-${i}', storageBlobDataContributerRoleId.id)
  scope: storageAccount
  properties: {
    roleDefinitionId: storageBlobDataContributerRoleId.id
    principalId: appServices[i].outputs.appServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}]

resource azureContainerRegistry 'Microsoft.ContainerRegistry/registries@2019-05-01' = if (enableConvertData) {
  name: azureContainerRegistryName
  location: location
  tags: union(tags, {
    displayName: 'Container Registry'
    'container.registry': azureContainerRegistryName
  })
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

@description('This is the built-in Key Vault Crypto Officer role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#acrpull')
resource acrPullRoleId 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = if (enableConvertData) {
  scope: subscription()
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
}

resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for i in range(0, appServiceCount): if (enableConvertData) {
  name: guid(subscription().id, '${serviceNameClean}-${i}', acrPullRoleId.id)
  scope: azureContainerRegistry
  properties: {
    roleDefinitionId: acrPullRoleId.id
    principalId: appServices[i].outputs.appServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}]
