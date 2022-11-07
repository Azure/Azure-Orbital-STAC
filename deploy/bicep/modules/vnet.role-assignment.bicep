// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param principalId string
param roleDefinitionId string

param vnetName string

param roleAssignmentId string = guid(principalId, roleDefinitionId, resourceGroup().name)

resource existingResource 'Microsoft.Network/virtualNetworks@2020-06-01' existing = {
  name: vnetName
}

resource symbolicname 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: roleAssignmentId
  scope: existingResource
  properties: {
    principalId: principalId
    roleDefinitionId: roleDefinitionId
  }
}

