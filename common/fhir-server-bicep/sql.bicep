param location string
param sqlServerName string
param sqlDatabaseName string
@allowed([
  'new'
  'existing'
])
param sqlServerNewOrExisting string
@secure()
param sqlAdminPassword string
param resourceTags object
param vaultName string
var newSql = sqlServerNewOrExisting == 'new'
var existingSql = sqlServerNewOrExisting == 'new'

resource newSqlServer 'Microsoft.Sql/servers@2023-02-01-preview' = if (newSql) {
  name: sqlServerName
  location: location
  tags: resourceTags
  properties: {
    administratorLogin: 'fhirAdmin'
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
  }

  resource newSqlServerAllowAllWindowIps 'firewallRules@2023-02-01-preview' = {
    name: 'AllowAllWindowsAzureIps'
    properties: {
      endIpAddress: '0.0.0.0'
      startIpAddress: '0.0.0.0'
    }
  }
}

resource existingSqlServer 'Microsoft.Sql/servers@2023-02-01-preview' existing = if (existingSql) {
  name: sqlServerName
}

resource sqlServerDatabase 'Microsoft.Sql/servers/databases@2023-02-01-preview' = {
  #disable-next-line use-parent-property - parent would have to be computed which isnt supported
  name: '${sqlServerName}/${sqlDatabaseName}'
  location: location
  tags: resourceTags
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

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: vaultName
}


resource newSqlServerConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'SqlServer--ConnectionString'
  properties: {
    contentType: 'text/plain'
    value: 'Server=tcp:${(newSql ? newSqlServer : existingSqlServer).properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlServerDatabase.name};Persist Security Info=False;User ID=${(newSql ? newSqlServer : existingSqlServer).properties.administratorLogin};Password=${sqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
  }
}
