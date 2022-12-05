// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param serviceBusName string
param serviceBusAccessingSubnetsList array
param existingNetworkRulesRules array
param publicNetworkAccess string = 'Enabled'
param defaultAction string = 'Deny'

param trustedServiceAccessEnabled bool = false
param ignoreMissingVnetServiceEndpoint bool = false

var virtualNetworkRules  = [for subnetId in serviceBusAccessingSubnetsList: {
  ignoreMissingVnetServiceEndpoint: ignoreMissingVnetServiceEndpoint, subnet: {id: subnetId}
}]

resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' existing = {
  name: serviceBusName
}

resource symbolicname 'Microsoft.ServiceBus/namespaces/networkRuleSets@2022-01-01-preview' = {
  name: 'default'
  parent: serviceBus
  properties: {
    defaultAction: defaultAction
    publicNetworkAccess: publicNetworkAccess
    trustedServiceAccessEnabled: trustedServiceAccessEnabled
    virtualNetworkRules: union(existingNetworkRulesRules, virtualNetworkRules)
  }
}
