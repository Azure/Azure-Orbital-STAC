// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param environmentName string
param acrName string
param keyVaultName string
param keyVaultResourceGroup string = resourceGroup().name
param containerRegistryLoginServerSecretName string = 'RegistryServer'
param containerRegistryUsernameSecretName string = 'RegistryUserName'
param containerRegistryPasswordSecretName string = 'RegistryPassword'
param randomSuffix string = uniqueString(subscription().id)

resource containerRepository 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' existing = {
  name: acrName
} 

module acrLoginServerNameSecret './akv.secrets.bicep' = {
  name: 'acr-login-server-name-${randomSuffix}'
  scope: resourceGroup(keyVaultResourceGroup)
  params: {
    environmentName: environmentName
    keyVaultName: keyVaultName
    secretName: containerRegistryLoginServerSecretName
    secretValue: containerRepository.properties.loginServer
  }
}

module acrUsernameSecret './akv.secrets.bicep' = {
  name: 'acr-username-${randomSuffix}'
  scope: resourceGroup(keyVaultResourceGroup)
  params: {
    environmentName: environmentName
    keyVaultName: keyVaultName
    secretName: containerRegistryUsernameSecretName
    secretValue: containerRepository.listCredentials().username
  }
}

module acrPasswordSecret './akv.secrets.bicep' = {
  name: 'acr-password-${randomSuffix}'
  scope: resourceGroup(keyVaultResourceGroup)
  params: {
    environmentName: environmentName
    keyVaultName: keyVaultName
    secretName: containerRegistryPasswordSecretName
    secretValue: containerRepository.listCredentials().passwords[0].value
  }
}
