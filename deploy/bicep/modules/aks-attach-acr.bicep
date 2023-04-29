// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param kubeletIdentityId string
param acrName string
param roleAssignmentId string = guid(kubeletIdentityId, kubeletIdentityId, acrName)

resource acr 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' existing = {
  name: acrName
}

resource acrPullRole 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: roleAssignmentId
  scope: acr
  properties: {
    principalId: kubeletIdentityId
    roleDefinitionId: acrPullRoleDefinition.id
  }
}

@description('This is the built-in AcrPull role. See https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#acrpull')
resource acrPullRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
}
