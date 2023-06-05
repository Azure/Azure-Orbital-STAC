// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param aksClusterPrincipalId string
param managedIdentityName string

param roleAssignmentId string = guid(managedIdentityName, aksClusterPrincipalId)

resource aadPodIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2021-09-30-preview' existing = {
  name: managedIdentityName
}

resource ManagedIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: roleAssignmentId
  scope: aadPodIdentity
  properties: {
    principalId: aksClusterPrincipalId
    roleDefinitionId: managedIdentityOperatorRoleDefinition.id
  }
  dependsOn:[
    aadPodIdentity   
  ]
}

@description('This is the built-in AcrPull role. See https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#managed-identity-operator')
resource managedIdentityOperatorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: 'f1a07417-d97a-45cb-824c-7a7467783830'
}
