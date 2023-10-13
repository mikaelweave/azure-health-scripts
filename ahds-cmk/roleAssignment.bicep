param principalIds array
param keyVaultName string

@description('This is the built-in Key Vault Crypto User role. See https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#key-vault-crypto-service-encryption-user')
resource keyValueCryptoUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'e147488a-f6f5-4113-8e2d-b22465e65bf6'
}

@description('This is the built-in Key Vault Administrator role. See https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#key-vault-administrator')
resource keyVaultAdministratorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '00482a5a-887f-4fb3-b363-3b7fe8e74483'
}

@description('This is the built-in Key Vault Crypto Officer role. See https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#key-vault-crypto-officer')
resource keyValueCryptoOfficerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '14b46e9e-c2b7-41b4-b07b-48a6ebf60603'
}

resource existingKeyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name : keyVaultName
}

resource keyVaultCryptoUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for principalId in principalIds : {
  name: guid(subscription().id, principalId, keyValueCryptoUserRoleDefinition.id)
  scope: existingKeyVault
  properties: {
    principalId: principalId
    roleDefinitionId: keyValueCryptoUserRoleDefinition.id
    principalType: 'ServicePrincipal'
  }
}]

resource keyVaultRoleAdministratorAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for principalId in principalIds : {
  name: guid(subscription().id, principalId, keyVaultAdministratorRoleDefinition.id)
  scope: existingKeyVault
  properties: {
    principalId: principalId
    roleDefinitionId: keyVaultAdministratorRoleDefinition.id
    principalType: 'ServicePrincipal'
  }
}]

resource keyVaultCryptoOfficerRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for principalId in principalIds : {
  name: guid(subscription().id, principalId, keyValueCryptoOfficerRoleDefinition.id)
  scope: existingKeyVault
  properties: {
    principalId: principalId
    roleDefinitionId: keyValueCryptoOfficerRoleDefinition.id
    principalType: 'ServicePrincipal'
  }
}]
