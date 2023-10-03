param principalId string

@description('This is the built-in Key Vault Crypto User role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-crypto-user')
resource keyValueCryptoUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '12338af0-0e69-4776-bea7-57ae8d297424'
}

resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().id, principalId, keyValueCryptoUserRoleDefinition.id)
  properties: {
    principalId: principalId
    roleDefinitionId: keyValueCryptoUserRoleDefinition.id
    principalType: 'ServicePrincipal'
  }
}
