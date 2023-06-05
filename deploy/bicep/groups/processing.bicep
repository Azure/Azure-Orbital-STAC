// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param environmentCode string
param environmentTag string
param location string
param projectName string

param keyVaultName string
param keyVaultResourceGroupName string
param logAnalyticsWorkspaceResourceID string
param acrName string = ''
param acrSku string = 'Standard'
param kubernetesVersion string

// Parameters for Virtual Network Information
param vnetName string
param vnetResourceGroup string
param vnetSubnetID string

// Parameters for AKS
param aksClusterName string = ''
param aksVmSize string = 'Standard_D2_v5'
param aksUserAgentPools array = [
  {
    name: 'stacpool'
    count: 8
  }
]
param aksNodePoolMaxPods int = 10

// Parameters for jumpbox
param jumpboxVmName string = ''
param jumpboxVmSize string = 'Standard_D2s_v5'

param aksManagedIdentityName string = ''

@description('Type of authentication to use on the Jumpbox Virtual Machine. SSH key is recommended.')
@allowed([
  'sshPublicKey'
  'password'
])
param jumpboxAuthenticationType string = 'password'
param jumpboxAdminUsername string = 'adminuser'
@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param jumpboxAdminPasswordOrKey string
param jumpboxSubnetID string
param jumpboxSshPort int = 22
param userManagedIdentityIdForJumpboxStateCheck string
param azureBastionSubnetID string
param azureBastionName string = ''

param ingressPublicIPDnsPrefix string = 'stac'

var namingPrefix = '${environmentCode}-${projectName}'
var namingSuffix = substring(uniqueString(guid('${subscription().subscriptionId}${namingPrefix}${environmentTag}${location}')), 0, 10)
var acrNameVar = empty(acrName) ? 'acr${namingSuffix}' : acrName
var aksClusterNameVar = empty(aksClusterName) ? 'aks${namingSuffix}' : aksClusterName
var aksManagedIdentityNameVar = empty(aksManagedIdentityName) ? '${namingPrefix}aks-mi' : aksManagedIdentityName
var jumpboxVmNameVar = empty(jumpboxVmName) ? 'jbox${namingSuffix}' : jumpboxVmName
var jumpboxAdminPasswordOrKeyVar = empty(jumpboxAdminPasswordOrKey) && jumpboxAuthenticationType == 'password' ?'${base64(uniqueString(guid(namingPrefix)))}' : jumpboxAdminPasswordOrKey
var bastionNameVar = empty(azureBastionName)? 'bastion${namingSuffix}' : azureBastionName
var ingressPublicIPDnsPrefixVar = empty(ingressPublicIPDnsPrefix) ? 'stac-${namingSuffix}' : ingressPublicIPDnsPrefix

module acr '../modules/acr.bicep' = {
  name: '${namingPrefix}-acr'
  params: {
    environmentName: environmentTag
    location: location
    acrName: acrNameVar
    acrSku: acrSku
  }
}

module acrCredentials '../modules/acr.credentials.to.keyvault.bicep' = {
  name: '${namingPrefix}-acr-credentials'
  params: {
    environmentName: environmentTag
    acrName: acr.outputs.name
    keyVaultName: keyVaultName
    keyVaultResourceGroup: keyVaultResourceGroupName
  }
}

module aksManagedIdentity '../modules/managed.identity.user.bicep' = {
  name: '${namingPrefix}-aks-managed-identity'
  params: {
    environmentName: environmentTag
    location: location
    uamiName: aksManagedIdentityNameVar
  }
}

module akvPolicyForMI '../modules/akv.policy.bicep' = {
  name: '${namingPrefix}-aks-policy-for-mi'
  scope: resourceGroup(keyVaultResourceGroupName)
  params: {
    keyVaultName: keyVaultName
    policyOps: 'add'
    objIdForPolicy: aksManagedIdentity.outputs.uamiPrincipalId
    secretPermission: [
      'Get'
      'List'
    ]
  }
}

module aksCluster '../modules/aks-cluster.bicep' =  {
  name: '${namingPrefix}-aks'
  params: {
    environmentName: environmentTag
    clusterName: aksClusterNameVar
    location: location
    logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceResourceID
    vmSize: aksVmSize
    networkPlugin: 'kubenet'
    vnetSubnetID: vnetSubnetID
    kubernetesVersion: kubernetesVersion
  }
}

module grantNetworkContributorOnVnetRGToAksCluster '../modules/vnet.role-assignment.bicep' = {
  name: '${namingPrefix}-aks-grant-network-contributor-on-vnet'
  scope: resourceGroup(vnetResourceGroup)
  params: {
    vnetName: vnetName
    principalId: aksCluster.outputs.principalId
    // Role definition id maps to 'Network Contributor' role
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7'
  }
}

module grantNetworkContributorOnProcessingRGToAksCluster '../modules/resourcegroup.role-assignment.bicep' = {
  name: '${namingPrefix}-aks-grant-network-contributor-on-processing-rg'
  params: {
    principalId: aksCluster.outputs.principalId
    // Role definition id maps to 'Network Contributor' role
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7'
  }
}

module grantNetworkResourceGroupReadAccessToAksCluster '../modules/resourcegroup.role-assignment.bicep' = {
  name: '${namingPrefix}-aks-grant-reader-to-vnet-rgp'
  scope: resourceGroup(vnetResourceGroup)
  params: {
    principalId: aksCluster.outputs.principalId
    // Role definition id maps to 'Reader' role
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7'
  }
}
module attachACRtoAKS '../modules/aks-attach-acr.bicep' =  {
  name: '${namingPrefix}-attachACRtoAKS'
  params: {
    kubeletIdentityId: aksCluster.outputs.kubeletIdentityId
    acrName:  acr.outputs.name
  }
}

module addUserAgentPools '../modules/aks-add-nodepool.bicep' = [ for (config, index) in aksUserAgentPools: {
  name: '${namingPrefix}-addUserAgentPools-${index}'
  params: {
    clusterName: aksCluster.outputs.name
    agentPoolName: config.name
    count: config.count
    maxPods: aksNodePoolMaxPods
    nodeLable: {
      env: config.name
    }
  }
}]

module jumpbox '../modules/virtual-machine.bicep' ={
  name : '${namingPrefix}-jumpbox'
  params: {
    vmName: jumpboxVmNameVar
    location: location
    vmSize: jumpboxVmSize
    adminUsername: jumpboxAdminUsername
    authenticationType: jumpboxAuthenticationType
    adminPasswordOrKey: jumpboxAdminPasswordOrKeyVar
    subnetID: jumpboxSubnetID
    environmentName: environmentTag
    sshPort: jumpboxSshPort
    userManagedIdentityIdForVMStateCheck: userManagedIdentityIdForJumpboxStateCheck
    customData: loadFileAsBase64('./cloud-init-ubuntu.txt')
  }
}

module jumpboxVmCredentials '../modules/vm.credentials.to.keyvault.bicep' = if (empty(jumpboxAdminPasswordOrKey)){
  name: '${namingPrefix}-jumpbox-vm-credentials'
  params: {
    environmentName: environmentTag
    keyVaultName: keyVaultName
    keyVaultResourceGroup: keyVaultResourceGroupName
    vmName: jumpboxVmNameVar
    vmHostname: jumpbox.outputs.hostname
    vmSshPort: string(jumpboxSshPort)
    vmUsername: jumpboxAdminUsername
    vmPassword: (jumpboxAuthenticationType == 'password')?jumpboxAdminPasswordOrKeyVar:'use-ssh-key'
  }
}

module azureBastion '../modules/bastion.bicep'= {
  name: '${namingPrefix}-bastion'
  params: {
    location: location
    environmentName: environmentTag
    bastionName: bastionNameVar
    bastionSubnetId: azureBastionSubnetID
  }
  dependsOn: [
    jumpbox
  ]
}

module ingressPublicIP '../modules/publicip.bicep' = {
  name: '${namingPrefix}-ingress-public-ip'
  params: {
    location: location
    name: '${namingPrefix}-ingress-public-ip'
    dnsLabelPrefix: ingressPublicIPDnsPrefixVar
  }
}
