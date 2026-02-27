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

// ── AKS Cluster ──
module aks 'modules/aks.bicep' = {
  name: 'aks-${environment}'
  params: {
    name: 'aks-${projectName}-${environment}'
    location: location
    environment: environment
    acrId: acr.outputs.acrId
  }
}

output aksClusterName string = aks.outputs.clusterName
output acrLoginServer string = acr.outputs.loginServer
