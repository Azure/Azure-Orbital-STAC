// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param privateDnsZoneName string

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
}

output id string = privateDnsZone.id
