// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

// -- parameter definition
@description('Region of the FHIR service')
param resourceLocation string = resourceGroup().location

@description('Workspace containing the Azure Health Data Services workspace')
param workspaceName string

@description('Name of FHIR service')
param fhirName string

@description('Kind of the FHIR service to update')
@allowed([
  'fhir-R4'
  'fhir-Stu3'
])
param fhirKind string = 'fhir-R4'

@description('Name of storage account to use for import. Needs to be an existing storage account.')
param storageName string

@description('Name of storage container to use for import. Needs to be an existing container. This deployment will add necessary permissions.')
param containerName string

@description('Flag to enable or disable $import')
param toggleImport bool

@description('Used to pull existing configuration from FHIR serviceß')
module existingFhir './existing_fhir.bicep' = {
  name: fhirName
  params: {
    fhirName: fhirName
    workspaceName: workspaceName
  }
}

@description('This is the existing AHDS workspace used to populate the updated resource')
resource existingWorkspace 'Microsoft.HealthcareApis/workspaces@2021-11-01' existing = {
  name: workspaceName
}

@description('Existing properties on the FHIR service')
var existingFhirProperties = existingFhir.outputs.properties

@description('If storage name is blank, leave the existing storage configuration')
var enableConfiguration = {
  enabled: true
  initialImportMode: true
  integrationDataStore: storageName
}

@description('Leave existing integrationDataStore property')
var disableConfiguration = contains(existingFhirProperties, 'importConfiguration') ? union(existingFhirProperties.importConfiguration, {
  enabled: false
  initialImportMode: false
}) : {
  enabled: false
  initialImportMode: false
}

var importConfiguration = union(existingFhirProperties.importConfiguration, toggleImport ? enableConfiguration : disableConfiguration)
var newProperties = union(existingFhirProperties, {
  importConfiguration: importConfiguration
})

@description('Updated FHIR Service used to enable import')
resource fhir 'Microsoft.HealthcareApis/workspaces/fhirservices@2021-11-01' = {
  name: fhirName
  parent: existingWorkspace
  location: resourceLocation
  kind: fhirKind

  identity: {
    type: 'SystemAssigned'
  }

  properties: newProperties

  dependsOn: [
    existingFhir
  ]
}

@description('Blob container used by FHIR service for $import')
resource importContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' existing = {
  name: '${storageName}/default/${containerName}'
}

@description('This is the built-in Storage Blob Data Contributor role. See https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor')
resource fhirContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

@description('This is the role assignment to give access to the Postman Client to the FHIR Service')
resource fhirDataContributorAccess 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: importContainer
  name: guid(importContainer.id, fhir.id, fhirContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: fhirContributorRoleDefinition.id
    principalId: fhir.identity.principalId
  }
}
