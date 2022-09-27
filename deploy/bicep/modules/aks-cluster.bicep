// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param environmentName string
param location string = resourceGroup().location 
param clusterName string
param nodeCount int = 3
param vmSize string = 'Standard_D2s_v4'
param networkPlugin string = 'azure'
param networkMode string = 'transparent'
param logAnalyticsWorkspaceResourceID string = ''
param vnetSubnetID string = ''

param managedIdentityName string = ''
param managedIdentityId string = ''
param managedIdentityClientId string = ''
param managedIdentityPrincipalId string = ''
param podIdentityNamespace string = '${managedIdentityName}-pod-identity-ns'
param podIdentityName string = '${managedIdentityName}-pod-identity'

resource aks 'Microsoft.ContainerService/managedClusters@2022-01-01' = {
  name: clusterName
  location: location
  tags: {
    environment: environmentName
    type: 'k8s'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: clusterName
    enableRBAC: true
    agentPoolProfiles: [
      {
        name: 'default'
        count: nodeCount
        vmSize: vmSize
        mode: 'System'
        nodeLabels: {
          App : 'default'
        }
        vnetSubnetID: (empty(vnetSubnetID) ? json('null') : vnetSubnetID)
      }
    ]
    addonProfiles: {
      omsagent: {
        enabled: empty(logAnalyticsWorkspaceResourceID)?false:true
        config: empty(logAnalyticsWorkspaceResourceID)?{}:{
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceResourceID
        }
      }
    }
    networkProfile: {
      networkPlugin: networkPlugin
      networkMode: networkMode
    }
    // Currently pod identity configuration works by default only with user-managed identity
    // For using with system managed identity use the module aks-cluster-with-pod-identity.bicep
    podIdentityProfile: {
      enabled: empty(managedIdentityName)?false:true
      allowNetworkPluginKubenet: networkPlugin=='kubenet'?true:false
      userAssignedIdentities: empty(managedIdentityName)?[]:[
        {
          identity: {
            clientId: managedIdentityClientId
            objectId: managedIdentityPrincipalId
            resourceId: managedIdentityId
          }
          name: podIdentityName
          namespace: podIdentityNamespace
        }
      ]
    }  
  }
}

output Id string = aks.id
output principalId string = aks.identity.principalId
output kubeletIdentityId string = aks.properties.identityProfile.kubeletidentity.objectId
