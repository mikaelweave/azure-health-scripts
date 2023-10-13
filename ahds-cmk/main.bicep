param workspaceName string
param managedIdentityName string
param keyVaultName string
param rsaKeyName string
param location string = resourceGroup().location
param deployNum string

@description('Managed identity used for testing UAMI CMK FHIR.')
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: managedIdentityName
  location: location
}

@description('Create the KeyVault to hold the CMK key.')
resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableSoftDelete: true
    enablePurgeProtection: true
    enabledForDiskEncryption: true
    enableRbacAuthorization: true
    tenantId: tenant().tenantId
  }
}

resource rsaKey 'Microsoft.KeyVault/vaults/keys@2019-09-01' = {
  name: rsaKeyName
  parent: keyVault
  properties: {
    keySize: 2048
    kty: 'RSA'
    keyOps: [
      'encrypt'
      'decrypt'
      'sign'
      'verify'
      'wrapKey'
      'unwrapKey'
    ]
  }
}

var samiFhirServiceName = 'samifhir${deployNum}'
var uamiFhirServiceName = 'uamifhir${deployNum}'

resource healthWorkspace 'Microsoft.HealthcareApis/workspaces@2022-06-01' =  {
  name: workspaceName
  location: location
}

#disable-next-line BCP081 - preview API version
resource fhirServiceSystemAssigned 'Microsoft.HealthcareApis/workspaces/fhirservices@2023-06-01-preview' = {
  name: samiFhirServiceName
  parent: healthWorkspace
  location: location
  kind: 'fhir-R4'
  properties: {
    authenticationConfiguration: {
      authority: '${environment().authentication.loginEndpoint}${tenant().tenantId}'
      audience: 'https://${workspaceName}-${samiFhirServiceName}.azurehealthcareapis.com'
      smartProxyEnabled: false
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// -- Module is required to get existing information from FHIR service
@description('Give FHIR instances access to the key vault before enabling CMK')
module miRoleAssignment './roleAssignment.bicep' = {
  name: 'ManagedIdentityKeyVaultRoleAssignment'
  params: {
    principalIds: [ managedIdentity.properties.principalId, fhirServiceSystemAssigned.identity.principalId ]
    keyVaultName: keyVault.name
  }
}

// -- Module is needed to deploy the FHIR service after it's been created to get sami id
@description('Used to pull existing configuration from FHIR service')
module fhirWithCMK './fhirServiceCmk.bicep' = {
  name: 'FhirServicesWithCMKEnabled'
  params: {
    workspaceName: workspaceName
    samiFhirServiceName: samiFhirServiceName
    uamiFhirServiceName: uamiFhirServiceName
    location: location
    keyUrl: rsaKey.properties.keyUriWithVersion
    uamiId: managedIdentity.id
  }

  dependsOn: [ fhirServiceSystemAssigned, miRoleAssignment ]
}
