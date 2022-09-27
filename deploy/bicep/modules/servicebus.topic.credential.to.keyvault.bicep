// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param environmentName string
param authorizationRuleId string
param authorizationRuleName string
param keyVaultName string
param keyVaultResourceGroup string = resourceGroup().name
param secretNamePrefix string = 'SB'
param utcValue string = utcNow()

module connectionString './akv.secrets.bicep' = {
  name: '${toLower(environmentName)}-${authorizationRuleName}-conn-${utcValue}'
  scope: resourceGroup(keyVaultResourceGroup)
  params: {
    environmentName: environmentName
    keyVaultName: keyVaultName
    secretName: '${secretNamePrefix}${authorizationRuleName}'
    secretValue: listKeys(authorizationRuleId, '2021-11-01').primaryConnectionString
  }
}
