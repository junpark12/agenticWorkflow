// ================================================================
// AKS + ACR 배포 메인 파일
// ================================================================

targetScope = 'resourceGroup'

@description('배포 환경')
@allowed(['dev', 'stg', 'prd'])
param environment string = 'dev'

@description('리전')
param location string = resourceGroup().location

@description('프로젝트 이름')
param projectName string = 'agenticwf'

// ── Container Registry ──
module acr 'modules/acr.bicep' = {
  name: 'acr-${environment}'
  params: {
    name: 'acr${projectName}${environment}'
    location: location
    sku: environment == 'prd' ? 'Premium' : 'Basic'
  }
}

// VNet 설정 (⚠️ 테스트: podCidr와 동일한 대역으로 의도적 충돌)
var vnetAddressPrefix = '10.10.0.0/16'   // AKS 서브넷 대역
var subnetPrefix = '10.10.0.0/24'        // 노드 서브넷

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-${projectName}-${environment}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]  // 10.10.0.0/16
    }
    subnets: [
      {
        name: 'aks-subnet'
        properties: {
          addressPrefix: subnetPrefix       // 10.10.0.0/24 (podCidr 10.10.0.0/16 범위 내 포함)
        }
      }
    ]
  }
}

// ── AKS Cluster ──
module aks 'modules/aks.bicep' = {
  name: 'aks-${environment}'
  params: {
    name: 'aks-${projectName}-${environment}'
    location: location
    environment: environment
    acrId: acr.outputs.acrId
    subnetId: vnet.properties.subnets[0].id   // VNet 서브넷 연결
  }
}

output aksClusterName string = aks.outputs.clusterName
output acrLoginServer string = acr.outputs.loginServer
