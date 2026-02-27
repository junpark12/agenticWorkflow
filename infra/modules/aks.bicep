// ================================================================
// Azure Kubernetes Service
// ================================================================

@description('AKS 클러스터 이름')
param name string

@description('리전')
param location string

@description('배포 환경')
@allowed(['dev', 'stg', 'prd'])
param environment string

@description('ACR 리소스 ID (이미지 풀 권한용)')
param acrId string

// 환경별 설정
var nodeCount = environment == 'prd' ? 3 : 1
var vmSize = environment == 'prd' ? 'Standard_D4s_v5' : 'Standard_D2s_v5'

resource aks 'Microsoft.ContainerService/managedClusters@2024-01-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: name
    kubernetesVersion: '1.29'

    // ── 네트워크 설정 ──
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'calico'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
      loadBalancerSku: 'standard'
    }

    // ── 노드 풀 ──
    agentPoolProfiles: [
      {
        name: 'systempool'
        count: nodeCount
        vmSize: vmSize
        mode: 'System'
        osType: 'Linux'
        osSKU: 'AzureLinux'
        enableAutoScaling: environment == 'prd'
        minCount: environment == 'prd' ? 2 : null
        maxCount: environment == 'prd' ? 5 : null
      }
    ]

    // ── API 서버 접근 제어 ──
    apiServerAccessProfile: {
      authorizedIPRanges: environment == 'prd' ? [
        '10.0.0.0/8'       // 내부 네트워크만
      ] : []                // dev: 제한 없음
      enablePrivateCluster: environment == 'prd'
    }

    // ── 보안 설정 ──
    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }
  }
}

// ACR Pull 권한 부여
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aks.id, acrId, 'acrpull')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: aks.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

output clusterName string = aks.name
output clusterFqdn string = aks.properties.fqdn
