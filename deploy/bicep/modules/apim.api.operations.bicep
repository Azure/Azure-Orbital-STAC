// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param apiManagementName string
param apiName string
param operations array

resource apiManagementService 'Microsoft.ApiManagement/service@2021-12-01-preview' existing = {
  name: apiManagementName
}

resource api 'Microsoft.ApiManagement/service/apis@2021-12-01-preview' existing = {
  parent: apiManagementService
  name: apiName
}

resource apiOperations 'Microsoft.ApiManagement/service/apis/operations@2021-12-01-preview' = [ for (operation, index) in operations:  {
  parent: api
  name: operation.name
  properties: operation.properties
}]

resource apiOperationsPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2021-12-01-preview' = [ for (operation, index) in operations: if (!empty(operation.policy)) {
  parent: apiOperations[index]
  name: 'policy'
  properties: operation.policy
}]
