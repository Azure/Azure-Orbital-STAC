// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param environmentName string
param applicationInsightsName string
param keyVaultName string
param keyVaultResourceGroup string = resourceGroup().name
param connectionStringSecretName string = 'AppInsightsConnectionString'
param randomSuffix string = uniqueString(subscription().id)

resource applicationInsights 'Microsoft.Insights/components@2020-02-02-preview' existing = {
  name: applicationInsightsName
} 

module acrLoginServerNameSecret './akv.secrets.bicep' = {
  name: 'appinsights-connstr-${randomSuffix}'
  scope: resourceGroup(keyVaultResourceGroup)
  params: {
    environmentName: environmentName
    keyVaultName: keyVaultName
    secretName: connectionStringSecretName
    secretValue: applicationInsights.properties.ConnectionString
  }
}
