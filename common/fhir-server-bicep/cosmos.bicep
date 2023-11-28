param cosmosDbAccountName string
param vaultName string
param location string
param resourceTags object
param cosmosDefaultConsistency string
param cosmosDbCmkUrl string

resource documentDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-09-15' = {
  tags: resourceTags
  name: cosmosDbAccountName
  location: location
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: cosmosDefaultConsistency
    }
    keyVaultKeyUri: cosmosDbCmkUrl
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: vaultName
}

resource serviceName_CosmosDb_Host 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'CosmosDb--Host'
  properties: {
    contentType: 'text/plain'
    value:  documentDbAccount.properties.documentEndpoint
  }
}

resource serviceName_CosmosDb_Key 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'CosmosDb--Key'
  properties: {
    contentType: 'text/plain'
    value: documentDbAccount.listKeys().primaryMasterKey
  }
}
