@description('Name of the Databricks workspace')
param workspaceName string

@description('Location for Azure Databricks workspack')
param location string

@allowed([
//  'standard'
  'premium'
])
@description('Tier for the Azure Databricks Service. Premium is required for Delta Live Tables.')
param tier string

@description('Resource tag for databricks')
param tags object = {}

@description('Principal IDs for administrators of the workspace')
param adminPrincipals array = []

@description('ID of the resource group for Databricks managed resources.')
param managedResourceGroupId string

resource databricks 'Microsoft.Databricks/workspaces@2022-04-01-preview' = {
  name: workspaceName
  location: location
  tags: tags
  sku: {
    name: tier
  }
  properties: {
    managedResourceGroupId: managedResourceGroupId
    publicNetworkAccess: 'Enabled'
  }
}

output databricksWorkspaceId string = databricks.id
output databricksWorkspaceUrl string = databricks.properties.workspaceUrl
