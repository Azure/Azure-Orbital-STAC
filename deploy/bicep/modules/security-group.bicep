// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param name string
param location string = resourceGroup().location
param securityRules array = []

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: name
  location: location
  properties: {
    securityRules: securityRules
  }
}


output id string = nsg.id
