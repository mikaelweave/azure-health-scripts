param fhirName string
param appTags object = {}

param tenantId string
param location string
param fhirContributorServicePrincipalObjectIds array = []

var loginURL = environment().authentication.loginEndpoint
var authority = '${loginURL}${tenantId}'
var audience = 'https://${fhirName}.azurehealthcareapis.com'


resource apiForFhir 'Microsoft.HealthcareApis/services@2021-06-01-preview' ={
  name: fhirName
  tags: appTags
  kind: 'fhir-R4'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties:{
    authenticationConfiguration: {
      audience: audience
      authority: authority
      smartProxyEnabled: false
    }
    cosmosDbConfiguration:{
        offerThroughput: 400
    }
  }
}

@description('This is the built-in FHIR Data Contributor role. See https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#fhir-data-contributor')
resource fhirContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '5a1fc7df-4bf1-4951-a576-89034ee01acd'
}

resource fhirDataContributorAccess 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' =  [for principalId in  fhirContributorServicePrincipalObjectIds: {
  scope: apiForFhir
  name: guid(apiForFhir.id, principalId, fhirContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: fhirContributorRoleDefinition.id
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}]
