// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param scriptContent string
param environmentVariables array
param userManagedIdentityId string = ''
param userManagedIdentityName string = ''
param userManagedIdentityResourcegroupName string = ''
param location string = resourceGroup().location
param randomSuffix string = uniqueString(subscription().id)

resource queryuserManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = if (empty(userManagedIdentityId)) {
  scope: resourceGroup(userManagedIdentityResourcegroupName)
  name: userManagedIdentityName
}

resource runAZCLIInlineWithOutput 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'runAZCLIInlineWithOutput${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: empty(userManagedIdentityId)? {
      '${queryuserManagedIdentity.id}': {}
    }: {
      '${userManagedIdentityId}': {}
    }
  }
  properties: {
    forceUpdateTag: randomSuffix
    azCliVersion: '2.28.0'
    environmentVariables: environmentVariables
    scriptContent: scriptContent
    timeout: 'PT1H'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'PT6H'
  }
}

output result object = runAZCLIInlineWithOutput.properties.outputs
