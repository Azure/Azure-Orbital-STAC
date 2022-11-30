// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param serviceBusName string

resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' existing = {
  name: serviceBusName
}

resource serviceBusExistingRule 'Microsoft.ServiceBus/namespaces/networkRuleSets@2022-01-01-preview' existing = {
  name: 'default'
  parent: serviceBus  
}

output existingRules array = serviceBusExistingRule.properties.virtualNetworkRules
