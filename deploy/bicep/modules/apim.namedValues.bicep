// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

@description('The name of the API Management service instance')
param apiManagementServiceName string

@description('The name of the named value to add')
param name string

@description('The value of the named value to add')
param value string

@description('The optional display name of the nameed value')
param displayName string = ''

resource apiManagementService 'Microsoft.ApiManagement/service@2021-12-01-preview' existing = {
  name: apiManagementServiceName
}

resource apiManagementNamedValue 'Microsoft.ApiManagement/service/namedValues@2022-04-01-preview' = {
  parent: apiManagementService
  name: name
  properties: {
    displayName: displayName == '' ? name : displayName
    value: value    
  }
}

output name string = apiManagementService.name
output principalId string = apiManagementService.identity.principalId
