param location string

param appServicePlanName string
param appServicePlanSku string
param numberOfInstances int
param appServiceName string

param deployApplicationInsights bool
param applicationInsightsLocation string
param combinedFhirServerConfigProperties object
param fhirVersion string
param imageTag string
param resourceTags object
param appInsightsName string

var appServiceResourceId = service.id
var deployAppInsights = deployApplicationInsights
var registryName = 'healthplatformregistry.azurecr.io'

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  kind: 'linux'
  tags: resourceTags
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
  name: appServiceName
  tags: resourceTags
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
    serverFarmId: appServicePlan.id
    clientAffinityEnabled: false
  }
}

resource serviceName_appsettings 'Microsoft.Web/sites/config@2018-11-01' = {
  parent: service
  name: 'appsettings'
  properties: (deployAppInsights ? union(combinedFhirServerConfigProperties, json('{"ApplicationInsights__InstrumentationKey": "${appInsights.properties.InstrumentationKey}"}')) : combinedFhirServerConfigProperties)
}

resource serviceName_web 'Microsoft.Web/sites/config@2018-11-01' = {
  parent: service
  name: 'web'
  properties: {
    linuxFxVersion: 'DOCKER|${registryName}/${toLower(fhirVersion)}_fhir-server:${imageTag}'
    appCommandLine: 'azure-fhir-api'
    alwaysOn: true
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
  tags: union({
    'hidden-link:${appServiceResourceId}': 'Resource'
    displayName: 'AppInsightsComponent'}, resourceTags)
  properties: {
    Application_Type: 'web'
  }
}

output appServicePrincipalId string = service.identity.principalId
