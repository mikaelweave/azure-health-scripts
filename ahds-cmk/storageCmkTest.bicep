param location string = resourceGroup().location
param keyVaultName string = 'mikaelwint3vault'
param rsaKeyName string = 'key1'

var tenantId = tenant().tenantId

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
    tenantId: tenantId
    accessPolicies: []
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

resource storageTest 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: 'mkcmkstortest123'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    encryption: {
      services: {
         blob: {
           enabled: true
         }
      }
      keySource: 'Microsoft.Keyvault'
      keyvaultproperties: {
        keyname: rsaKey.name
        keyvaulturi: endsWith(keyVault.properties.vaultUri,'/') ? substring(keyVault.properties.vaultUri,0,length(keyVault.properties.vaultUri)-1) : keyVault.properties.vaultUri
      }
    }
  }
}
