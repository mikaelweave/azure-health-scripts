param storageAccountName string
param appInsightsName string
param appServiceName string
param functionAppName string
param location string
param appTags object = {}


// Function Storage Account
resource funcStorageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  tags: appTags
}

// App Insights resource
resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: appTags
}

// App Service
resource appService 'Microsoft.Web/serverFarms@2020-06-01' = {
  name: appServiceName
  location: location
  kind: 'functionapp'
  sku: {
    name: 'S1'
  }
  tags: appTags
}

// Function App
resource functionApp 'Microsoft.Web/sites@2020-12-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'

  identity: {
    type: 'SystemAssigned'
  }

  properties: {
    httpsOnly: true
    enabled: true
    serverFarmId: appService.id
    clientAffinityEnabled: false
    siteConfig: {
      alwaysOn:true
    }
  }

  tags: appTags
}

resource fhirProxyAppSettings 'Microsoft.Web/sites/config@2020-12-01' = {
  name: 'appsettings'
  parent: functionApp
  properties: {
    'FUNCTIONS_EXTENSION_VERSION': '~4'
    'FUNCTIONS_WORKER_RUNTIME': 'dotnet'
    'AzureWebJobsStorage': 'DefaultEndpointsProtocol=https;AccountName=${funcStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${funcStorageAccount.listKeys().keys[0].value}'
    'APPINSIGHTS_INSTRUMENTATIONKEY': appInsights.properties.InstrumentationKey
    'APPLICATIONINSIGHTS_CONNECTION_STRING': 'InstrumentationKey=${appInsights.properties.InstrumentationKey}'
  }
}
