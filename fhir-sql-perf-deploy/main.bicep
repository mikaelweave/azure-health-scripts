@description('Name of the FHIR service Web App.')
@minLength(3)
@maxLength(24)
param serviceName string

@description('Resource group containing App Service Plan. If empty, deployment resource group is used.')
param appServicePlanResourceGroup string = ''

@description('Name of App Service Plan (existing or new). If empty, a name will be generated.')
param appServicePlanName string = ''

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
param appServicePlanSku string = 'P3V3'

@description('Sets the number of instances to deploy for the app service.')
param numberOfInstances int = 30

@description('OAuth Authority')
param securityAuthenticationAuthority string = ''

@description('Audience (aud) to validate in JWT')
param securityAuthenticationAudience string = ''

@description('Enable Azure AAD SMART on FHIR Proxy')
param enableAadSmartOnFhirProxy bool = false

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
param sqlAdminPassword string

@description('An override location for the sql server database.')
param sqlLocation string = resourceGroup().location

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
param imageTag string = '20231013.1'

@description('Determines whether export will be enabled for this fhir instance. If true, a storage account will be created as part of the deployment. You will need owner or user-administrator permissions for this.')
param enableExport bool = true

@description('Determines whether the $convert-data operation will be enabled for this fhir instance. If true, an Azure container registry will be created as part of the deployment. You will need owner or user-administrator permissions for this.')
param enableConvertData bool = false

@description('Determines whether the $reindex operation will be enabled for this fhir instance.')
param enableReindex bool = true

@description('Determines whether the $import operation will be enabled for this fhir instance.')
param enableImport bool = true

@description('Supports parallel background task running')
param backgroundTaskCount int = 2

param location string = resourceGroup().location

var serviceNameClean = toLower(serviceName)
var keyvaultEndpoint = 'https://${serviceNameClean}${environment().suffixes.keyvaultDns}/'
var appServicePlanResourceGroupClean = (empty(appServicePlanResourceGroup) ? resourceGroup().name : appServicePlanResourceGroup)
var appServicePlanResourceGroupCleanappServicePlanNameClean = (empty(appServicePlanName) ? '${serviceNameClean}-asp' : appServicePlanName)
var appServiceResourceId = service.id
var securityAuthenticationEnabled = ((!empty(securityAuthenticationAuthority)) && (!empty(securityAuthenticationAudience)))
var deployAppInsights = deployApplicationInsights
var appInsightsName = 'AppInsights-${serviceNameClean}'
var enableIntegrationStore = (enableExport || enableImport)
var staticFhirServerConfigProperties = {
  APPINSIGHTS_PORTALINFO: 'ASP.NETCORE'
  APPINSIGHTS_PROFILERFEATURE_VERSION: '1.0.0'
  APPINSIGHTS_SNAPSHOTFEATURE_VERSION: '1.0.0'
  WEBSITE_NODE_DEFAULT_VERSION: '6.9.4'
  KeyVault__Endpoint: keyvaultEndpoint
  FhirServer__Security__Enabled: securityAuthenticationEnabled
  FhirServer__Security__EnableAadSmartOnFhirProxy: enableAadSmartOnFhirProxy
  FhirServer__Security__Authentication__Authority: securityAuthenticationAuthority
  FhirServer__Security__Authentication__Audience: securityAuthenticationAudience
  CosmosDb__ContinuationTokenSizeLimitInKb: '1'
  SqlServer__Initialize: true
  SqlServer__SchemaOptions__AutomaticUpdatesEnabled: ((sqlSchemaAutomaticUpdatesEnabled == 'auto') ? true : false)
  DataStore: 'SqlServer'
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
var sqlServerDerivedName = (empty(sqlServerName) ? serviceNameClean : sqlServerName)
var sqlDatabaseName = 'FHIR${fhirVersion}'
var storageAccountName = '${substring(replace(serviceNameClean, '-', ''), 0, min(11, length(replace(serviceNameClean, '-', ''))))}${uniqueString(resourceGroup().id, serviceNameClean)}'
var registryName = 'healthplatformregistry.azurecr.io'
var azureContainerRegistryName = '${substring(replace(serviceNameClean, '-', ''), 0, min(11, length(replace(serviceNameClean, '-', ''))))}${uniqueString(resourceGroup().id, serviceNameClean)}'

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = if (empty(appServicePlanResourceGroup)) {
  name: appServicePlanResourceGroupCleanappServicePlanNameClean
  kind: 'linux'
  tags: {
    FhirServerSolution: 'SqlServer'
  }
  location: location
  sku: {
    name: appServicePlanSku
    capacity: numberOfInstances
  }
  properties: {
    targetWorkerCount: numberOfInstances
    maximumElasticWorkerCount: numberOfInstances
    reserved: true
  }
}

resource service 'Microsoft.Web/sites@2018-11-01' = {
  name: serviceNameClean
  tags: {
    FhirServerSolution: 'SqlServer'
  }
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${registryName}'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: ''
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: ''
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'true'
        }
      ]
      scmType: 'None'
      ftpsState: 'Disabled'
    }
    serverFarmId: resourceId(appServicePlanResourceGroupClean, 'Microsoft.Web/serverfarms/', appServicePlanResourceGroupCleanappServicePlanNameClean)
    clientAffinityEnabled: false
  }
  dependsOn: [
    appServicePlan
  ]
}

resource serviceName_appsettings 'Microsoft.Web/sites/config@2018-11-01' = {
  parent: service
  name: 'appsettings'
  properties: (deployAppInsights ? union(combinedFhirServerConfigProperties, json('{"ApplicationInsights__InstrumentationKey": "${appInsights.properties.InstrumentationKey}"}')) : combinedFhirServerConfigProperties)
  dependsOn: [
    sqlServerDerivedName_sqlDatabase
  ]
}

resource serviceName_web 'Microsoft.Web/sites/config@2018-11-01' = {
  parent: service
  name: 'web'
  properties: {
    linuxFxVersion: 'DOCKER|${registryName}/${toLower(fhirVersion)}_fhir-server:${imageTag}'
    appCommandLine: 'azure-fhir-api'
    alwaysOn: true
    healthCheckPath: '/health/check'
  }
}

resource serviceName_scm 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2020-12-01' = {
  parent: service
  name: 'scm'
  kind: 'string'
  properties: {
    allow: false
  }
}

resource serviceName_ftp 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2020-12-01' = {
  parent: service
  name: 'ftp'
  kind: 'string'
  properties: {
    allow: false
  }
}

resource appInsights 'Microsoft.Insights/components@2015-05-01' = if (deployAppInsights) {
  name: appInsightsName
  location: applicationInsightsLocation
  kind: 'web'
  tags: {
    'hidden-link:${appServiceResourceId}': 'Resource'
    displayName: 'AppInsightsComponent'
    FhirServerSolution: 'SqlServer'
  }
  properties: {
    Application_Type: 'web'
  }
}


resource sqlServerDerived 'Microsoft.Sql/servers@2015-05-01-preview' = if (sqlServerNewOrExisting == 'new') {
  name: sqlServerDerivedName
  location: sqlLocation
  tags: {
    FhirServerSolution: 'SqlServer'
  }
  properties: {
    administratorLogin: 'fhirAdmin'
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
  }
}

resource sqlServerDerivedName_sqlDatabase 'Microsoft.Sql/servers/databases@2017-10-01-preview' = if (sqlServerNewOrExisting == 'new') {
  parent: sqlServerDerived
  location: sqlLocation
  tags: {
    FhirServerSolution: 'SqlServer'
  }
  name: sqlDatabaseName
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 4398046511104
    readScale: 'Disabled'
    zoneRedundant: false
  }
  sku: {
    name: 'GP_Gen5_40'
    tier: 'GeneralPurpose'
  }
}

resource sqlServerDerivedName_AllowAllWindowsAzureIps 'Microsoft.Sql/servers/firewallrules@2014-04-01' = if (sqlServerNewOrExisting == 'new') {
  parent: sqlServerDerived
  name: 'AllowAllWindowsAzureIps'
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
}

resource Microsoft_KeyVault_vaults_service 'Microsoft.KeyVault/vaults@2015-06-01' = {
  name: serviceNameClean
  location: location
  tags: {
    FhirServerSolution: 'SqlServer'
  }
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    accessPolicies: [
      {
        tenantId: tenant().tenantId
        objectId: service.identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
            'set'
          ]
        }
      }
    ]
    enabledForDeployment: false
  }
}

resource serviceName_SqlServer_ConnectionString 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: Microsoft_KeyVault_vaults_service
  name: 'SqlServer--ConnectionString'
  properties: {
    contentType: 'text/plain'
    value: 'Server=tcp:${sqlServerDerived.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlServerDerivedName_sqlDatabase.name};Persist Security Info=False;User ID=${sqlServerDerived.properties.administratorLogin};Password=${sqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
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

@description('This is the built-in Key Vault Crypto Officer role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#acrpull')
resource storageBlobDataContributerRoleId 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

resource storageBlobContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (enableIntegrationStore) {
  name: guid(subscription().id, serviceNameClean, storageBlobDataContributerRoleId.id)
  scope: storageAccount
  properties: {
    roleDefinitionId: storageBlobDataContributerRoleId.id
    principalId: service.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource azureContainerRegistry 'Microsoft.ContainerRegistry/registries@2019-05-01' = if (enableConvertData) {
  name: azureContainerRegistryName
  location: location
  tags: {
    displayName: 'Container Registry'
    'container.registry': azureContainerRegistryName
  }
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

resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (enableConvertData) {
  name: guid(subscription().id, serviceNameClean, acrPullRoleId.id)
  scope: azureContainerRegistry
  properties: {
    roleDefinitionId: acrPullRoleId.id
    principalId: service.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
