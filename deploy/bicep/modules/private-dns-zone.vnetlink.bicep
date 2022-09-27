// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param privateDnsZoneName string
param vnetLinkName string
param customVnetId string

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateDnsZoneName
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: vnetLinkName
  location: 'global'
  properties : {
    registrationEnabled: false
    virtualNetwork: {
      id: customVnetId
    }
  }
}

output id string = privateDnsZoneLink.id
