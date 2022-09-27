// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param aksClusterPrincipalId string
param managedIdentityName string

// managedIdentityOperatorRole is mapped to role definition "Managed Identity Operator"
param managedIdentityOperatorRole string = '/providers/Microsoft.Authorization/roleDefinitions/f1a07417-d97a-45cb-824c-7a7467783830'
param roleAssignmentId string = guid(managedIdentityName, aksClusterPrincipalId)

resource aadPodIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2021-09-30-preview' existing = {
  name: managedIdentityName
}

resource ManagedIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: roleAssignmentId
  scope: aadPodIdentity
  properties: {
    principalId: aksClusterPrincipalId
    roleDefinitionId: managedIdentityOperatorRole
  }
  dependsOn:[
    aadPodIdentity   
  ]
}
