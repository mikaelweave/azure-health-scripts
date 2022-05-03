param groupUniqueString string
param prefix string
param tenantId string = subscription().tenantId
param location string = resourceGroup().location
param adminPrincipalIds array = []
@allowed([
  'fhirService'
  'apiForFhir'
])
param fhirType string = 'fhirService'
@secure()
param privateServicePrincipal object
@secure()
param publicServicePrincipal object
@secure()
param functionServicePrincipal object

// Resource names
var name = '${prefix}-${groupUniqueString}'
var workspaceName = format('{0}ahds', replace(name, '-', ''))
var fhirName = 'fhirdata'
var apiForFhirName = format('{0}fhir', replace(name, '-', ''))
var storageAccountName = format('{0}sa', replace(name, '-', ''))
var appServiceName = '${name}-plan'
var appInsightsName = '${name}-insight'
var logAnalyticsName = '${name}-logs'
var functionAppName = '${name}-func'
var vaultName = '${name}-kv'
var fhirServiceUrl = 'https://${workspaceName}-${fhirName}.fhir.azurehealthcareapis.com'
var apiForfhirUrl = 'https://${apiForFhirName}.azurehealthcareapis.com'
var fhirUrl = fhirType == 'fhirService' ? fhirServiceUrl : apiForfhirUrl

var appTags = {
  AppID: 'fhir-proxy-sample'
}

module fhir './fhir.bicep'= if (fhirType == 'fhirService') {
  name: 'fhirDeploy'
  params: {
    workspaceName: workspaceName
    fhirName: fhirName
    location: location
    tenantId: tenantId
    fhirContributorServicePrincipalObjectIds: [
      proxyFunction.outputs.functionAppPrincipalId
      privateServicePrincipal.enterpriseObjectId
    ]
    appTags: appTags
  }

  dependsOn: [
    keyvault
    proxyFunction
  ]
}

module apiForfhir './apiForFhir.bicep'= if (fhirType == 'apiForFhir') {
  name: 'apiForFhirDeploy'
  params: {
    fhirName: apiForFhirName
    location: location
    tenantId: tenantId
    fhirContributorServicePrincipalObjectIds: [
      proxyFunction.outputs.functionAppPrincipalId
      privateServicePrincipal.enterpriseObjectId
    ]
    appTags: appTags
  }

  dependsOn: [
    keyvault
    proxyFunction
  ]
}

module proxyFunction './proxyFunction.bicep' = {
  name: 'proxyFunctionDeploy'
  params: {
    storageAccountName: storageAccountName
    appInsightsName: appInsightsName
    logAnalyticsName: logAnalyticsName
    appServiceName: appServiceName
    functionAppName: functionAppName
    location: location
    appTags: appTags
    tenantId: tenantId
    keyVaultName: keyvault.outputs.keyVaultName
    functionServicePrincipal: functionServicePrincipal
  }
}

var secrets = {
  'FS-URL': fhirUrl
  'FS-TENANT-NAME': privateServicePrincipal.tenant
  'FS-CLIENT-NAME': privateServicePrincipal.displayName
  'FS-CLIENT-ID': privateServicePrincipal.appId
  'FS-SECRET': privateServicePrincipal.password
  'FS-CLIENT-SECRET': privateServicePrincipal.password
  'FS-OBJECT-ID': privateServicePrincipal.objectId
  'FS-RESOURCE': fhirUrl
  'FP-RBAC-TENANT-NAME': functionServicePrincipal.tenant
  'FP-RBAC-CLIENT-ID': functionServicePrincipal.appId
  'FP-RBAC-CLIENT-SECRET': functionServicePrincipal.password
  'FP-SC-TENANT-NAME': publicServicePrincipal.tenant
  'FP-SC-CLIENT-ID': publicServicePrincipal.appId
  'FP-SC-SECRET': publicServicePrincipal.password
  'FP-SC-RESOURCE': privateServicePrincipal.appId
}

module keyvault './keyvault.bicep' = {
  name: 'keyVaultDeploy'
  params: {
    name: vaultName
    location: location
    tenantId: tenantId
    keyAdminPrincipals: adminPrincipalIds
    defaultSecrets: secrets
    appTags: appTags
  }
}

output functionAppName string = functionAppName
