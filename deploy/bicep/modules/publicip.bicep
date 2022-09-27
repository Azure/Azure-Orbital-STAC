// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param name string
param location string = resourceGroup().location
param dnsLabelPrefix string
param skuName string = 'Standard'
param skuTier string = 'Regional'
param publicIPAllocationMethod string = 'Static'
param publicIPAddressVersion string = 'IPV4'
param idleTimeoutInMinutes int = 5

resource publicIP 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: name
  location: location
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    publicIPAllocationMethod: publicIPAllocationMethod
    publicIPAddressVersion: publicIPAddressVersion
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
    idleTimeoutInMinutes: idleTimeoutInMinutes
  }
}

output id string = publicIP.id
output hostname string = publicIP.properties.dnsSettings.fqdn
