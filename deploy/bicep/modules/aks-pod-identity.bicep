// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param environmentName string

param clusterName string
param location string = resourceGroup().location

param nodeCount int = 3
param vmSize string = 'Standard_D2s_v4'
param networkPlugin string = 'azure'
param networkMode string = 'transparent'
param logAnalyticsWorkspaceResourceID string = ''
param vnetSubnetID string = ''

param managedIdentityName string
param managedIdentityResourcegroupName string
param managedIdentityId string
param managedIdentityClientId string
param managedIdentityPrincipalId string
param podIdentityNamespace string = '${managedIdentityName}-pod-identity-ns'
param podIdentityName string = '${managedIdentityName}-pod-identity'

resource aksCluster 'Microsoft.ContainerService/managedClusters@2022-01-01' existing = {
  name: clusterName
}

module assignAccess '../modules/assign-managed-identity-operator-to-aks.bicep' =  {
  name: '${clusterName}-assign-access'
  scope: resourceGroup(managedIdentityResourcegroupName)
  params: {
    aksClusterPrincipalId: aksCluster.identity.principalId
    managedIdentityName: managedIdentityName
  }
  dependsOn:[
    aksCluster
  ]
}

module assignPodIdentity '../modules/aks-cluster.bicep' =  {
  name: '${clusterName}-aks-assign-pod-identity'
  params: {
    environmentName: environmentName
    clusterName: clusterName
    location: location
    nodeCount: nodeCount
    vmSize: vmSize
    networkPlugin: networkPlugin
    networkMode: networkMode
    logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceResourceID
    vnetSubnetID: vnetSubnetID
    managedIdentityName: managedIdentityName
    managedIdentityId: managedIdentityId
    managedIdentityClientId: managedIdentityClientId
    managedIdentityPrincipalId: managedIdentityPrincipalId
    podIdentityNamespace: podIdentityNamespace
    podIdentityName: podIdentityName
  }
  dependsOn:[
    assignAccess
  ]
}
