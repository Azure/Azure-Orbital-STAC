// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param name string
param topicName string
param serviceBusNamespace string

resource topic 'Microsoft.ServiceBus/namespaces/topics@2021-11-01' existing = {
  name: '${serviceBusNamespace}/${topicName}'
}

resource subscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2021-11-01' = {
  name: name
  parent: topic
  properties: {
    isClientAffine: false
    lockDuration: 'PT30S'
    requiresSession: false
    defaultMessageTimeToLive: 'P14D'
    deadLetteringOnMessageExpiration: false
    deadLetteringOnFilterEvaluationExceptions: false
    maxDeliveryCount: 2000
    status: 'Active'
    enableBatchedOperations: true
    autoDeleteOnIdle: 'P14D'
  }
}

resource subscriptionDefaultRule 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2021-11-01' = {
  parent: subscription
  name: 'Default'
  properties: {
    action: {
    }
    filterType: 'SqlFilter'
    sqlFilter: {
      sqlExpression: '1=1'
      compatibilityLevel: 20
    }
  }
}
