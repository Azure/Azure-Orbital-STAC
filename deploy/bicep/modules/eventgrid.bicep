// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param name string
param location string = resourceGroup().location
param sourceId string
param topicType string
param logAnalyticsId string = ''
param retentionDays int = 14

resource eventGridTopic 'Microsoft.EventGrid/systemTopics@2021-12-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    source: sourceId
    topicType: topicType
  }
}

resource diagnosticLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsId)) {
  name: '${name}-diagnosticLogs'
  scope: eventGridTopic
  properties: {
    workspaceId: logAnalyticsId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          days: retentionDays
          enabled: true
        }
      }
    ]
  }
}

output name string = eventGridTopic.name
output principalId string = eventGridTopic.identity.principalId
