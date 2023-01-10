// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

targetScope='subscription'

@description('Location for all the resources to be deployed')
param location string

@minLength(3)
@maxLength(9)
@description('Prefix to be used for naming all the resources in the deployment')
param environmentCode string

@description('Environment will be used as Tag on the resource group')
param environment string

@description('Ower AAD object ID to setup this environment')
param owner_aad_object_id string

@description('Postgres DB administrator login password')
@secure()
param postgresAdminLoginPass string = ''
// Parameters with default values for Keyvault
param keyvaultName string = ''

param cloudEndpoints object = loadJsonContent('../cloud_endpoints.json')

param randomSuffix string = uniqueString(subscription().id)
param pgPrivateDNSZoneName string = 'privatelink${cloudEndpoints.suffixes.postgresqlServerEndpoint}'

@description('Jumpbox administrator username')
param jumpboxAdminUsername string = 'adminuser'
@description('Jumpbox administrator login password')
@secure()
param jumpboxAdminPassword string

// Guid to role definitions to be used during role
// assignments including the below roles definitions:
// Contributor
param uamiRole string = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

var monitoringResourceGroupName = '${environmentCode}-monitoring-rg'
var vnetResourceGroupName = '${environmentCode}-vnet-rg'
var dataResourceGroupName = '${environmentCode}-data-rg'
var processingResourceGroupName = '${environmentCode}-processing-rg'
var projectName = 'stac'
var namingPrefix = '${environmentCode}-${projectName}'

param loadBalancerPrivateIP string = '10.6.3.254'

// This parameter is a placeholder to retain current work we have for public access
// Setting it to true may not work for all cases.
// Setting it to true may need future work
param enablePublicAccess bool = false
var namingSuffix = substring(uniqueString(guid('${subscription().subscriptionId}${namingPrefix}${environmentCode}${location}')), 0, 10)
var keyvaultNameVar = empty(keyvaultName) ? 'kv${namingSuffix}' : keyvaultName
var vnetNameVar = '${namingPrefix}-vnet'
var uamiNameVar = '${namingPrefix}-umi'
var resourceGroupNamesToMonitor = [
  monitoringResourceGroupName
  vnetResourceGroupName
  dataResourceGroupName
  processingResourceGroupName
]

module monitoringRg 'modules/resourcegroup.bicep' = {
  name : monitoringResourceGroupName
  scope: subscription()
  params: {
    environmentName: environment
    resourceGroupName: monitoringResourceGroupName
    resourceGroupLocation: location
  }
}

module uami 'modules/managed.identity.user.bicep' = {
  name: '${namingPrefix}-umi'
  scope: resourceGroup(monitoringRg.name)
  params: {
    environmentName: environment
    location: location
    uamiName: uamiNameVar
  }
}


module vnetRg 'modules/resourcegroup.bicep' = {
  name : vnetResourceGroupName
  scope: subscription()
  params: {
    environmentName: environment
    resourceGroupName: vnetResourceGroupName
    resourceGroupLocation: location
  }
}

module dataRg 'modules/resourcegroup.bicep' = {
  name : dataResourceGroupName
  scope: subscription()
  params: {
    environmentName: environment
    resourceGroupName: dataResourceGroupName
    resourceGroupLocation: location
  }
}

module processingRg 'modules/resourcegroup.bicep' = {
  name : processingResourceGroupName
  scope: subscription()
  params: {
    environmentName: environment
    resourceGroupName: processingResourceGroupName
    resourceGroupLocation: location
  }
}

module monitoringModule 'groups/monitoring.bicep' = {
  name: '${namingPrefix}-monitoring'
  scope: resourceGroup(monitoringRg.name)
  params: {
    projectName: projectName
    location: location
    keyVaultName: keyvaultNameVar
    keyVaultResourceGroupName: dataRg.name
    environmentCode: environmentCode
    environmentTag: environment
  }
  dependsOn: [
    uami
    vnetRg
    monitoringRg
    dataRg
    processingRg
  ]
}

module uamiRoleAssignment 'modules/resourcegroup.role-assignment.bicep' = [ for (resourceGroupName, index) in resourceGroupNamesToMonitor: {
  name: '${namingPrefix}-uami-role-assignment-${index}'
  scope: resourceGroup(resourceGroupName)
  params: {
    principalId: uami.outputs.uamiPrincipalId
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${uamiRole}'
  }
  dependsOn: [
    monitoringModule
  ]
}]

module checkVnetExists 'modules/vnet.exists.bicep' = {
  name : '${namingPrefix}-checkVnetExists${randomSuffix}'
  scope: resourceGroup(vnetRg.name)
  params: {
    userManagedIdentityId: uami.outputs.uamiId
    vnetName: vnetNameVar
    location: location
  }
  dependsOn: [
    uamiRoleAssignment
  ]
}

module networkingModule 'groups/networking.bicep' = {
  name: '${namingPrefix}-networking'
  scope: resourceGroup(vnetRg.name)
  params: {
    environmentCode: environmentCode
    location: location
    projectName: projectName
    environmentTag: environment
    virtualNetworkName: vnetNameVar
    pgPrivateDNSZoneName: pgPrivateDNSZoneName
    newOrExisting: checkVnetExists.outputs.vnetExists ? 'existing' : 'new'
  }
}

module dataModule 'groups/data.bicep' = {
  name: '${namingPrefix}-data'
  scope: resourceGroup(dataRg.name)
  params: {
    projectName: projectName
    location: location
    environmentCode: environmentCode
    environmentTag: environment
    enablePublicAccess: enablePublicAccess
    keyvaultName: keyvaultNameVar
    owner_aad_object_id: owner_aad_object_id
    postgresAdminLoginPass: postgresAdminLoginPass
    vnetResourceGroupName: vnetRg.name
    dataSubnetId: networkingModule.outputs.dataSubnetId
    serviceBusAccessingSubnetsList: networkingModule.outputs.serviceBusAccessingSubnetsList
    pgDelegatedSubnetId: networkingModule.outputs.pgDelegatedSubnetId
    pgPrivateDNSZoneId: networkingModule.outputs.pgPrivateDNSZoneId
    storageAccountPrivateDNSZoneName: networkingModule.outputs.storageAccountPrivateDNSZoneName
    logAnalyticsWorkspaceResourceID: monitoringModule.outputs.workspaceId
  }
}

module processingModule 'groups/processing.bicep' = {
  name: '${namingPrefix}-processing'
  scope: resourceGroup(processingRg.name)
  params: {
    projectName: projectName
    location: location
    environmentCode: environmentCode
    environmentTag: environment
    keyVaultName: keyvaultNameVar
    keyVaultResourceGroupName: dataRg.name
    logAnalyticsWorkspaceResourceID: monitoringModule.outputs.workspaceId
    vnetResourceGroup: vnetResourceGroupName
    vnetName: vnetNameVar
    vnetSubnetID: networkingModule.outputs.aksSubnetId
    userManagedIdentityIdForJumpboxStateCheck: uami.outputs.uamiId
    jumpboxSubnetID: networkingModule.outputs.jumpboxSubnetId
    jumpboxAdminUsername: jumpboxAdminUsername
    jumpboxAdminPasswordOrKey: jumpboxAdminPassword
    loadBalancerPrivateIP: loadBalancerPrivateIP
    storageAccountNameForApim: dataModule.outputs.storageAccountName
    storageAccountResourceGroupName: dataRg.name
    apimSubnetId: networkingModule.outputs.apimSubnetId
    azureBastionSubnetID: networkingModule.outputs.bastionSubnetId
  }
  dependsOn: [
    dataModule
  ]
}

module appinsightsSecrets 'modules/appinsights.credentials.to.keyvault.bicep' = {
  name : '${namingPrefix}-appinsights-secrets'
  scope: resourceGroup(monitoringRg.name)
  params: {
    environmentName: environment
    applicationInsightsName: '${namingPrefix}-appinsights'
    keyVaultName: dataModule.outputs.keyVaultName
    keyVaultResourceGroup: dataResourceGroupName
  }
  dependsOn: [
    dataModule
  ]
}
