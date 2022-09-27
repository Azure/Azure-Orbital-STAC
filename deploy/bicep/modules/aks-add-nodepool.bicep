// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param clusterName string
param agentPoolName string
param agentPoolMode string = 'User'
param count int = 3
param vmSize string = 'Standard_D2_v5'
param nodeLable object = {
  env: 'dev'
}
param vnetSubnetID string = ''

resource aksNodePool 'Microsoft.ContainerService/managedClusters/agentPools@2022-01-01' = {
  name: '${clusterName}/${agentPoolName}'
  properties: {
    count: count
    vmSize: vmSize
    mode: agentPoolMode
    type: 'VirtualMachineScaleSets'
    nodeLabels: nodeLable
    vnetSubnetID: (empty(vnetSubnetID) ? json('null') : vnetSubnetID)
  }
}
