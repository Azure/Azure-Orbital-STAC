// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param environmentName string
param name string
param location string = resourceGroup().location
param sku string = 'Premium'
param skuCapacity int = 1

resource servicebus 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' = {
  name: name
  location: location
  sku: {
    name: sku
    tier: sku
    capacity: skuCapacity
  }
  tags: {
    environment: environmentName
  }
}

resource servicebus_RootManageSharedAccessKey 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2021-11-01' = {
  parent: servicebus
  name: 'RootManageSharedAccessKey'
  properties: {
    rights: [
      'Listen'
      'Manage'
      'Send'
    ]
  }
}

output authorizationRuleId string = servicebus_RootManageSharedAccessKey.id
output authorizationRuleName string = servicebus_RootManageSharedAccessKey.name
