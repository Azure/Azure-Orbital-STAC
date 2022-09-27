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

param managedIdentityName string = ''
param managedIdentityResourcegroupName string = ''
param managedIdentityId string = ''
param managedIdentityClientId string = ''
param managedIdentityPrincipalId string = ''
param podIdentityNamespace string = '${managedIdentityName}-pod-identity-ns'
param podIdentityName string = '${managedIdentityName}-pod-identity'

var configurePodIdentity = empty(managedIdentityName)||empty(managedIdentityResourcegroupName)||empty(managedIdentityId)||empty(managedIdentityClientId)||empty(managedIdentityPrincipalId)?false:true

module aksCluster '../modules/aks-cluster.bicep' =  {
  name: '${clusterName}-aks-cluster'
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
  }
}

module assignPodIdentityToAksCluster '../modules/aks-pod-identity.bicep' = if(configurePodIdentity) {
  name: '${clusterName}-assign-pod-identity-to-aks'
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
    managedIdentityResourcegroupName: managedIdentityResourcegroupName
    managedIdentityId: managedIdentityId
    managedIdentityClientId: managedIdentityClientId
    managedIdentityPrincipalId: managedIdentityPrincipalId
    podIdentityNamespace: podIdentityNamespace
    podIdentityName: podIdentityName
  }
  dependsOn: [
    aksCluster
  ]
}

output Id string = aksCluster.outputs.Id
output principalId string = aksCluster.outputs.principalId
output kubeletIdentityId string = aksCluster.outputs.kubeletIdentityId
