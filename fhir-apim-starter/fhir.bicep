@allowed([
  'deploy'
  'reference'
])
param deployOrReference string
param workspaceName string
param fhirServiceName string
param tenantId string
param location string
param tags object = {}

var loginURL = environment().authentication.loginEndpoint
var authority = '${loginURL}${tenantId}'
var audience = 'https://${workspaceName}-${fhirServiceName}.fhir.azurehealthcareapis.com'

resource deployHealthWorkspace 'Microsoft.HealthcareApis/workspaces@2021-06-01-preview' = if (deployOrReference == 'deploy') {
  name: workspaceName
  location: location
  tags: tags
}

resource deployFhir 'Microsoft.HealthcareApis/workspaces/fhirservices@2021-06-01-preview' = if (deployOrReference == 'deploy') {
  name: '${workspaceName}/${fhirServiceName}'
  location: location
  kind: 'fhir-R4'

  identity: {
    type: 'SystemAssigned'
  }

  properties: {
    authenticationConfiguration: {
      authority: authority
      audience: audience
      smartProxyEnabled: false
    }
  }

  tags: tags

  dependsOn: [
    deployHealthWorkspace
  ]
}

resource existingFhir 'Microsoft.HealthcareApis/workspaces/fhirservices@2021-06-01-preview' existing = {
  name: '${workspaceName}/${fhirServiceName}'
}

output fhirId string = deployOrReference == 'deploy' ? deployFhir.id : existingFhir.id
output fhirServiceUrl string = 'https://${workspaceName}-${fhirServiceName}.fhir.azurehealthcareapis.com'
