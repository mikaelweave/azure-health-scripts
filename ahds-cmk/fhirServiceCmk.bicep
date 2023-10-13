param workspaceName string
param samiFhirServiceName string
param uamiFhirServiceName string
param location string
param keyUrl string // rsaKey.properties.keyUriWithVersion
param uamiId string // managedIdentity.id

resource healthWorkspace 'Microsoft.HealthcareApis/workspaces@2022-06-01' existing =  {
  name: workspaceName
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
    encryption: {
      customerManagedKeyEncryption: {
        keyEncryptionKeyUrl: keyUrl
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

#disable-next-line BCP081 - preview API version
resource fhirServiceUserAssigned 'Microsoft.HealthcareApis/workspaces/fhirservices@2023-06-01-preview' = {
  name: uamiFhirServiceName
  parent: healthWorkspace
  location: location
  kind: 'fhir-R4'
  properties: {
    authenticationConfiguration: {
      authority: '${environment().authentication.loginEndpoint}${tenant().tenantId}'
      audience: 'https://${workspaceName}-${uamiFhirServiceName}.azurehealthcareapis.com'
      smartProxyEnabled: false
    }
    encryption: {
      customerManagedKeyEncryption: {
        keyEncryptionKeyUrl: keyUrl
      }
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
}
