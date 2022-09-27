// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param eventGridName string
param events array
param serviceBusNamespace string

resource servicebusTopics 'Microsoft.ServiceBus/namespaces/topics@2021-11-01' existing = [for event in events: {
  name: '${serviceBusNamespace}/${event.serviceBusTopicName}'
}]

resource eventGridTopic 'Microsoft.EventGrid/systemTopics@2021-12-01' existing = {
  name: eventGridName
}

resource serviceBusEndpointTypeSubscriptions 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2021-12-01' = [for (event, index) in events: {
  parent: eventGridTopic
  name: event.name
  properties: {
    deliveryWithResourceIdentity: {
      identity:{
        type: 'SystemAssigned'
      }
      destination:{
        properties: {
          resourceId: servicebusTopics[index].id
        }
        endpointType: event.endpointType
      }
    }
    filter: event.filter
    labels: []
    eventDeliverySchema: 'EventGridSchema'
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440
    }
  }
}]
