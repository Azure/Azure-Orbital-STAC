// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

@description('The name of the API Management service instance')
param parentResourceName string
param apiName string
param properties object
param policy object
param document object = {}
param apiSchemaContentType string ='application/vnd.oai.openapi.components+json'
var apiSechemaName = '${apiName}-schema'

resource apiManagementService 'Microsoft.ApiManagement/service@2021-12-01-preview' existing = {
  name: parentResourceName
}

resource api 'Microsoft.ApiManagement/service/apis@2021-12-01-preview' = {
  parent: apiManagementService
  name: apiName
  properties: properties
}

resource apiSchema 'Microsoft.ApiManagement/service/apis/schemas@2021-12-01-preview' = if (document != {}) {
  parent: api
  name: apiSechemaName
  properties: {
    contentType: apiSchemaContentType
    document: document
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2021-12-01-preview' = {
  parent: api
  name: 'policy'
  properties: policy
}
