// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param name string
param serviceBusAccessingSubnetsList array
param publicNetworkAccess string = 'Enabled'
param defaultAction string = 'Deny'

param trustedServiceAccessEnabled bool = false
param ignoreMissingVnetServiceEndpoint bool = false
module serviceBusExistingNetworkRules '../modules/servicebus.existingrules.bicep' = {
  name: '${name}-existing-vnet-rule'
  params:{
    serviceBusName: name
  }
}

module serviceBusNetwork '../modules/servicebus.vnet.access.bicep' = {
  name: '${name}-vnet-rule'
  params: {
    serviceBusName: name
    publicNetworkAccess: publicNetworkAccess
    defaultAction: defaultAction
    trustedServiceAccessEnabled: trustedServiceAccessEnabled
    ignoreMissingVnetServiceEndpoint: ignoreMissingVnetServiceEndpoint
    existingNetworkRulesRules: serviceBusExistingNetworkRules.outputs.existingRules
    serviceBusAccessingSubnetsList: serviceBusAccessingSubnetsList
  }
  dependsOn:[
    serviceBusExistingNetworkRules
  ]
}
