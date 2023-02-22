// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param environmentCode string
param environmentTag string
param location string
param projectName string
param owner_aad_object_id string
param vnetResourceGroupName string
param serviceBusAccessingSubnetsList array = []
param dataSubnetId string
param logAnalyticsWorkspaceResourceID string = ''
@secure()
param postgresAdminLoginPass string = ''
// Parameters with default values for Keyvault
param keyvaultName string
param keyvaultSkuName string = 'Standard'
param keyvaultCertPermission array = [
  'All'
]
param keyvaultKeyPermission array = [
  'All'
]
param keyvaultScrtPermission array = [
  'All'
]
param keyvaultStoragePermission array = [
  'All'
]
param keyvaultUsePublicIp bool = true
param keyvaultPublicNetworkAccess bool = true
param keyvaultEnabledForDeployment bool = true
param keyvaultEnabledForDiskEncryption bool = true
param keyvaultEnabledForTemplateDeployment bool = true
param keyvaultEnablePurgeProtection bool = true
param keyvaultEnableRbacAuthorization bool = false
param keyvaultEnableSoftDelete bool = true
param keyvaultSoftDeleteRetentionInDays int = 7

// pg related parameters
param pgHaMode string = 'Disabled'
param pgDelegatedSubnetId string
param pgPrivateDNSZoneId string
param privateEndpointDisabled bool

// Parameters for storage account
param storageAccountName string = ''
param storageAccountPrivateDNSZoneName string

// storage account containers
param storageContainerNames array = [
  'stacify'
  'pgstac'
  'staccollection'
]

param servicebusSku string = 'Premium'
param servicebusSkuCapacity int = 1
// Service Bus Data Sender Role Definition Guid
param serviceBusDataSenderRoleGuid string = '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'


// Topics to be setup in Service Bus
param serviceBusTopicsConfig array = [
  {
    name: 'pgstactopic'
    authorizationRuleName: 'pgstacpolicy'
    defaultSubscription: 'pgstacsubscription'
  }
  {
    name: 'stacifytopic'
    authorizationRuleName: 'stacifypolicy'
    defaultSubscription: 'stacifysubscription'
  }
  {
    name: 'staccollectiontopic'
    authorizationRuleName: 'staccollectionpolicy'
    defaultSubscription: 'staccollectionsubscription'
  }
]

// Event Grid and event subscriptions of Service bus endpoint type
param eventGridTopicsConfig object = {
  type: 'Microsoft.Storage.StorageAccounts'
  events: [
    {
      name: 'stacify-event'
      endpointType: 'ServiceBusTopic'
      serviceBusTopicName: 'stacifytopic'
      containerName: 'stacify'
      filter: {
        includedEventTypes: [
          'Microsoft.Storage.BlobCreated'
        ]
        subjectBeginsWith: '/blobServices/default/containers/stacify'
        subjectEndsWith: '.tif'
        enableAdvancedFilteringOnArrays: true
      }
    }
    {
      name: 'pgstac-event'
      endpointType: 'ServiceBusTopic'
      serviceBusTopicName: 'pgstactopic'
      containerName: 'pgstac'
      filter: {
        includedEventTypes: [
          'Microsoft.Storage.BlobCreated'
        ]
        subjectBeginsWith: '/blobServices/default/containers/pgstac'
        subjectEndsWith: '.json'
        enableAdvancedFilteringOnArrays: true
      }
    }
    {
      name: 'staccollection-event'
      endpointType: 'ServiceBusTopic'
      serviceBusTopicName: 'staccollectiontopic'
      containerName: 'staccollection'
      filter: {
        includedEventTypes: [
          'Microsoft.Storage.BlobCreated'
        ]
        subjectBeginsWith: '/blobServices/default/containers/staccollection'
        subjectEndsWith: '.json'
        enableAdvancedFilteringOnArrays: true
      }
    }
  ]
}

// This parameter is a placeholder to retain current work we have for public access
// Setting it to true may not work for all cases.
// Setting it to true may need future work
param enablePublicAccess bool = false

var resourceGroupNameVar = resourceGroup().name
var namingPrefix = '${environmentCode}-${projectName}'
var namingPrefixWithoutDash = replace(namingPrefix, '-', '')
var namingSuffix = substring(uniqueString(guid('${subscription().subscriptionId}${namingPrefix}${environmentTag}${location}')), 0, 10)
var keyvaultNameVar = empty(keyvaultName) ? 'kv${namingSuffix}' : keyvaultName
var storageAccountNameVar = empty(storageAccountName) ? '${namingPrefixWithoutDash}${namingSuffix}' : storageAccountName
var servicebusNamespaceNameVar = 'sb${namingSuffix}'
var eventGridTopicsConfigNameVar = 'stactopic${namingSuffix}'
var pgserverNameVar = 'pg${namingSuffix}'
var postgresAdminLoginPassVar = empty(postgresAdminLoginPass) ? '${uniqueString(guid(namingPrefix))}!' : postgresAdminLoginPass
var postgresAdminLoginVar = '${environmentCode}_admin_user'

module keyVault '../modules/akv.bicep' = {
  name: '${namingPrefix}-akv'
  params: {
    environmentName: environmentTag
    keyVaultName: keyvaultNameVar
    location: location
    skuName:keyvaultSkuName
    objIdForAccessPolicyPolicy: owner_aad_object_id
    certPermission:keyvaultCertPermission
    keyPermission:keyvaultKeyPermission
    scrtPermission:keyvaultScrtPermission
    storagePermission:keyvaultStoragePermission
    usePublicIp: keyvaultUsePublicIp
    publicNetworkAccess:keyvaultPublicNetworkAccess
    enabledForDeployment: keyvaultEnabledForDeployment
    enabledForDiskEncryption: keyvaultEnabledForDiskEncryption
    enabledForTemplateDeployment: keyvaultEnabledForTemplateDeployment
    enablePurgeProtection: keyvaultEnablePurgeProtection
    enableRbacAuthorization: keyvaultEnableRbacAuthorization
    enableSoftDelete: keyvaultEnableSoftDelete
    softDeleteRetentionInDays: keyvaultSoftDeleteRetentionInDays
  }
}

module storageAccount '../modules/storage.bicep' =  {
  name: '${namingPrefix}-storage'
  params: {
    storageAccountName: storageAccountNameVar
    environmentName: environmentTag
    location: location
    public_access:enablePublicAccess?'Enabled':'Disabled'

  }
}

module storageAccountCredentials '../modules/storage.credentials.to.keyvault.bicep' = {
  name: '${namingPrefix}-storage-credentials'
  params: {
    environmentName: environmentTag
    storageAccountName: storageAccountNameVar
    keyVaultName: keyvaultNameVar
    keyVaultResourceGroup: resourceGroupNameVar
    secretNamePrefix: environmentCode
  }
  dependsOn: [
    keyVault
    storageAccount
  ]
}

module storageAccountBlobPrivateEndPoint '../modules/private-endpoint.bicep' =  {
  name: '${namingPrefix}-storage-blob-private-endpoint'
  scope: resourceGroup(vnetResourceGroupName)
  params: {
    environmentCode: environmentCode
    groupIds: [
      'blob'
    ]
    location: location
    privateDnsZoneName: storageAccountPrivateDNSZoneName
    privateLinkServiceId: storageAccount.outputs.storageAccountId
    subnetId: dataSubnetId
  }
}

module pgServer '../modules/postgres.flexible.svc.bicep' = {
  name: '${namingPrefix}-postgres'
  params:{
    administratorLogin: postgresAdminLoginVar
    administratorLoginPassword: postgresAdminLoginPassVar
    location: location
    serverName: pgserverNameVar
    delegatedSubnetResourceId: pgDelegatedSubnetId
    privateDnsZoneArmResourceId: pgPrivateDNSZoneId
    privateEndpointDisabled: privateEndpointDisabled
    haMode: pgHaMode
  }
}

module pgAdministratorLoginPassword '../modules/akv.secrets.bicep' = {
  name: '${namingPrefix}-postgres-credential-to-kv'
  params: {
    environmentName: environmentTag
    keyVaultName: keyvaultNameVar
    secretName: 'PGAdminLoginPass'
    secretValue: postgresAdminLoginPassVar
  }
  dependsOn: [
    keyVault
    pgServer
  ]
}

module storageContainers '../modules/storage.container.bicep' = [for(containerName, index) in storageContainerNames: {
  name: '${namingPrefix}-storage-container-${index}'
  params: {
    storageAccountName: storageAccountNameVar
    containerName: containerName
  }
  dependsOn: [
    storageAccount
  ]
}]

module servicebus '../modules/servicebus.bicep' = {
  name: '${namingPrefix}-servicebus'
  params: {
    environmentName: environmentTag
    location: location
    name: servicebusNamespaceNameVar
    sku: servicebusSku
    skuCapacity: servicebusSkuCapacity
  }
}

module servicebusVNet '../modules/servicebus.secured.vnet.bicep' =  {
  name: '${namingPrefix}-vnet-secured-servicebus'
  params: {
    name: servicebusNamespaceNameVar
    serviceBusAccessingSubnetsList: serviceBusAccessingSubnetsList
    defaultAction: enablePublicAccess?'Allow':'Deny'
    trustedServiceAccessEnabled: true // this is needed for eventgrid to be allowed to bypass the firewall rules
  }
  dependsOn: [
    servicebus
  ]
}

module servicebusTopics '../modules/servicebus.topic.bicep' = [for (topic, index) in serviceBusTopicsConfig: {
  name: '${namingPrefix}-topic-${index}'
  params: {
    name: topic.name
    auhorizationRuleName: topic.authorizationRuleName
    serviceBusNamespace: servicebusNamespaceNameVar
    serviceBusSku: servicebusSku
  }
  dependsOn: [
    servicebus
  ]
}]

module servicebusTopicsConnectionString '../modules/servicebus.topic.credential.to.keyvault.bicep' = {
  name: '${namingPrefix}-svcbus-connection-string'
  params: {
    environmentName: environmentTag
    authorizationRuleId: servicebus.outputs.authorizationRuleId
    keyVaultName: keyvaultNameVar
    keyVaultResourceGroup: resourceGroupNameVar
  }
  dependsOn: [
    keyVault
    servicebus
  ]
}

module servicebusTopicsDefaultSubscription '../modules/servicebus.topic.subscription.bicep' = [for (topic, index) in serviceBusTopicsConfig: {
  name: '${namingPrefix}-topics-sub-${index}'
  params: {
    name: topic.defaultSubscription
    topicName: topic.name
    serviceBusNamespace: servicebusNamespaceNameVar
  }
  dependsOn: [
    servicebusTopics
  ]
}]

module eventGridTopics '../modules/eventgrid.bicep' = {
  name: '${namingPrefix}-eventgrid-topic'
  params: {
    name: eventGridTopicsConfigNameVar
    location: location
    topicType: eventGridTopicsConfig.type
    sourceId: storageAccount.outputs.storageAccountId
    logAnalyticsId: logAnalyticsWorkspaceResourceID
  }
}

module grantServiceBusDataSenderRoleToEventGrid '../modules/servicebus-role-assignment.bicep' = {
  name: '${namingPrefix}-servicebus-data-sender-role-grant'
  params: {
    resourceName: servicebusNamespaceNameVar
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/${serviceBusDataSenderRoleGuid}'
    principalId: eventGridTopics.outputs.principalId
  }
  dependsOn: [
    servicebusTopicsConnectionString
    eventGridTopics
  ]
}

module eventGridServiceBusTopicsSubscription '../modules/eventgrid.serviceBus.subscription.bicep' = {
  name: '${namingPrefix}-eventgrid-topic-subs'
  params: {
    events: eventGridTopicsConfig.events
    serviceBusNamespace: servicebusNamespaceNameVar
    eventGridName: eventGridTopicsConfigNameVar
  }
  dependsOn: [
    storageContainers
    grantServiceBusDataSenderRoleToEventGrid
  ]
}

output storageAccountName string = storageAccountNameVar
output keyVaultName string = keyvaultNameVar
