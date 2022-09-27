// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param environmentName string
param location string = resourceGroup().location

param vmName string
param runCommandName string
param script string
param runAsUser string = ''
param asyncExecution bool = false
//Timeout in seconds for script execution defaulting to 5 mins
param executionTimeout int = 300

resource vm 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: vmName
}
resource runCommand 'Microsoft.Compute/virtualMachines/runCommands@2022-03-01' = {
  name: runCommandName
  location: location
  tags: {
    environment: environmentName
  }
  parent: vm
  properties: {
    runAsUser: (runAsUser == '')?null:runAsUser
    source: {
      script: script
    }
    asyncExecution: asyncExecution
    timeoutInSeconds: executionTimeout
  }
}
