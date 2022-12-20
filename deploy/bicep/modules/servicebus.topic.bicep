// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param name string
param serviceBusNamespace string
param auhorizationRuleName string

param serviceBusSku string = 'Standard'
param maxMessageSizeInKilobytes int = toLower(serviceBusSku)=='premium'?1024:256

resource servicebus 'Microsoft.ServiceBus/namespaces@2022-01-01-preview' existing = {
  name: serviceBusNamespace
}

resource topic 'Microsoft.ServiceBus/namespaces/topics@2021-11-01' = {
  name: name
  parent: servicebus
  properties: {
    maxMessageSizeInKilobytes: maxMessageSizeInKilobytes
    defaultMessageTimeToLive: 'P14D'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    status: 'Active'
    supportOrdering: true
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    enablePartitioning: false
    enableExpress: false
  }
}

resource topicAuthorizationRule 'Microsoft.ServiceBus/namespaces/topics/authorizationrules@2021-11-01' = {
  parent: topic
  name: auhorizationRuleName
  properties: {
    rights: [
      'Manage'
      'Listen'
      'Send'
    ]
  }
}

output id string = topic.id
output authorizationRuleId string = topicAuthorizationRule.id
output authorizationRuleName string = topicAuthorizationRule.name
