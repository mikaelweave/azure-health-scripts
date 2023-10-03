param workspaceName string
param fhirServiceName string
param managedIdentityName string
param keyVaultName string
param rsaKeyName string = 'fhircmk'
param location string = resourceGroup().location

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
    tenantId: tenant().tenantId
    accessPolicies: []
  }

  resource rsaKey 'keys' = {
    name: rsaKeyName
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
}

// -- Module is required to get existing information from FHIR service
@description('Used to pull existing configuration from FHIR service')
module uamRoleAssignment './roleAssignment.bicep' = {
  name: 'ManagedIdentityKeyVaultRoleAssignment'
  params: {
    principalId: managedIdentity.properties.principalId
  }
}

#disable-next-line BCP081 - preview API version
resource fhirService 'Microsoft.HealthcareApis/workspaces/fhirservices@2023-06-01-preview' = {
  name: '${workspaceName}/${fhirServiceName}'
  location: location
  kind: 'fhir-R4'  // This is an example, choose the version you want.
  properties: {
    authenticationConfiguration: {
      authority: '${environment().authentication.loginEndpoint}${tenant().tenantId}'
      audience: 'https://${workspaceName}-${fhirServiceName}.azurehealthcareapis.com'
      smartProxyEnabled: false
    }
  }
  identity: {
    type: 'UserAssigned'
    #disable-next-line BCP037 - linter not detecting UAMI correctly
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
}
