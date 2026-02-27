// ================================================================
// Azure Container Registry
// ================================================================

@description('ACR 이름')
param name string

@description('리전')
param location string

@description('SKU')
@allowed(['Basic', 'Standard', 'Premium'])
param sku string = 'Basic'

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: name
  location: location
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}

output acrId string = acr.id
output loginServer string = acr.properties.loginServer
