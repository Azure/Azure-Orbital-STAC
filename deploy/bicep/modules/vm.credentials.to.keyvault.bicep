// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param environmentName string
param keyVaultName string
param keyVaultResourceGroup string = resourceGroup().name
param vmName string
param vmHostnameSecretName string = '${vmName}-HostName'
param vmHostname string
param vmSshPortSecretName string = '${vmName}-SshPort'
param vmSshPort string
param vmUsernameSecretName string = '${vmName}-UserName'
param vmUsername string
param vmPasswordSecretName string = '${vmName}-Password'
@secure()
param vmPassword string
param vmSshConnectionStringSecretName string = '${vmName}-SshConnectionString'
param vmSshConnectionString string = 'ssh -p ${vmSshPort} ${vmUsername}@${vmHostname}'
param randomSuffix string = uniqueString(subscription().id)


module vmHostNameSecret './akv.secrets.bicep' = {
  name: 'vm-host-name-${randomSuffix}'
  scope: resourceGroup(keyVaultResourceGroup)
  params: {
    environmentName: environmentName
    keyVaultName: keyVaultName
    secretName: vmHostnameSecretName
    secretValue: vmHostname
  }
}

module vmSshPortSecret './akv.secrets.bicep' = {
  name: 'vm-ssh-port-${randomSuffix}'
  scope: resourceGroup(keyVaultResourceGroup)
  params: {
    environmentName: environmentName
    keyVaultName: keyVaultName
    secretName: vmSshPortSecretName
    secretValue: vmSshPort
  }
}

module vmUsernameSecret './akv.secrets.bicep' = {
  name: 'vm-username-${randomSuffix}'
  scope: resourceGroup(keyVaultResourceGroup)
  params: {
    environmentName: environmentName
    keyVaultName: keyVaultName
    secretName: vmUsernameSecretName
    secretValue: vmUsername
  }
}

module vmPasswordSecret './akv.secrets.bicep' = {
  name: 'vm-password-${randomSuffix}'
  scope: resourceGroup(keyVaultResourceGroup)
  params: {
    environmentName: environmentName
    keyVaultName: keyVaultName
    secretName: vmPasswordSecretName
    secretValue: vmPassword
  }
}

module vmSshConnectionStringSecret './akv.secrets.bicep' = {
  name: 'vm-ssh-connection-string-${randomSuffix}'
  scope: resourceGroup(keyVaultResourceGroup)
  params: {
    environmentName: environmentName
    keyVaultName: keyVaultName
    secretName: vmSshConnectionStringSecretName
    secretValue: vmSshConnectionString
  }
}
