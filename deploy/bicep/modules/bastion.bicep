// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param environmentName string
param location string = resourceGroup().location
param bastionName string
param bastionSubnetId string
param publicIPAddressName string = '${bastionName}PublicIP'
param dnsLabelPrefix string = toLower('${bastionName}-${uniqueString(resourceGroup().id)}')

module publicIP './publicip.bicep' = {
  name: publicIPAddressName
  params: {
    name: publicIPAddressName
    location: location
    dnsLabelPrefix: dnsLabelPrefix
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2020-06-01' = {
  name: bastionName
  location: location
  tags: {
    environment: environmentName
  }
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: bastionSubnetId
          }
          publicIPAddress: {
            id: publicIP.outputs.id
          }
        }
      }
    ]
  }
}

output id string = bastionHost.id
