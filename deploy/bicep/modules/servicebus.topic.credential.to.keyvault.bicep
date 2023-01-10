// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param environmentName string
param authorizationRuleId string
param keyVaultName string
param secretName string = 'ServiceBusConnectionString'
param keyVaultResourceGroup string = resourceGroup().name
param randomSuffix string = uniqueString(subscription().id)

module connectionString './akv.secrets.bicep' = {
  name: '${toLower(environmentName)}-${secretName}-connstr-${randomSuffix}'
  scope: resourceGroup(keyVaultResourceGroup)
  params: {
    environmentName: environmentName
    keyVaultName: keyVaultName
    secretName: secretName
    secretValue: listKeys(authorizationRuleId, '2021-11-01').primaryConnectionString
  }
}
