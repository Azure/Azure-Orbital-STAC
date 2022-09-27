// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

@description('The name of the API Management service instance')
param apiManagementServiceName string = 'apiservice${uniqueString(resourceGroup().id)}'

@description('The email address of the owner of the service')
@minLength(1)
param publisherEmail string

@description('The name of the owner of the service')
@minLength(1)
param publisherName string

@description('The pricing tier of this API Management service')
@allowed([
  'Developer'
  'Standard'
  'Premium'
])
param sku string = 'Developer'

@description('The instance size of this API Management service.')
@allowed([
  1
  2
])
param skuCount int = 1

@description('Location for all resources.')
param location string = resourceGroup().location

@description('custom properties for the API Management service')
param customProperties object = {
  'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'false'
  'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls12': 'false'
  'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'false'
  'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'false'
  'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'false'
  'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'false'
  'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168': 'false'
  'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'false'
}

@allowed([
  'None'
  'External'
  'Internal'
])
param virtualNetworkType string = 'None'

@allowed([
  'Disabled'
  'Enabled'
])
param publicNetworkAccess string = 'Enabled'

param subnetId string = ''
param dnsLabelPrefix string = toLower('${apiManagementServiceName}-${uniqueString(resourceGroup().id)}')

module publicIp './publicip.bicep' = if (virtualNetworkType!='None') {
  name: '${apiManagementServiceName}-public-ip'
  params: {
    name: '${apiManagementServiceName}-public-ip'
    location: location
    dnsLabelPrefix: dnsLabelPrefix
  }
}

resource apiManagementService 'Microsoft.ApiManagement/service@2021-12-01-preview' = {
  name: apiManagementServiceName
  location: location
  sku: {
    name: sku
    capacity: skuCount
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    customProperties: customProperties
    virtualNetworkType: virtualNetworkType
    virtualNetworkConfiguration: empty(subnetId)?null:{
      subnetResourceId: subnetId
    }
    publicIpAddressId: publicIp.outputs.id
    publicNetworkAccess: publicNetworkAccess
  }
  dependsOn:[
    publicIp
  ]
}

output name string = apiManagementService.name
output principalId string = apiManagementService.identity.principalId
