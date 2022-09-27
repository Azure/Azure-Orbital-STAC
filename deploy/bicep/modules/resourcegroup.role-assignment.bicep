// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param principalId string
param roleDefinitionId string

param roleAssignmentId string = guid(principalId, roleDefinitionId, resourceGroup().name)

resource symbolicname 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: roleAssignmentId
  scope: resourceGroup()
  properties: {
    principalId: principalId
    roleDefinitionId: roleDefinitionId
  }
}
