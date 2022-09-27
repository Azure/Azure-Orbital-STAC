// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param vNetName string
param subnetName string
param subnetAddressPrefix string
param serviceEndPoints array = []
param delegations array = []
param privateEndpointNetworkPolicies string = 'Disabled'
param privateLinkServiceNetworkPolicies string = 'Disabled'
param nsgId string = ''

//Subnet with RT and NSG
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-08-01' = {
  name: '${vNetName}/${subnetName}'
  properties: {
    addressPrefix: subnetAddressPrefix
    serviceEndpoints: serviceEndPoints
    delegations: delegations
    privateEndpointNetworkPolicies: privateEndpointNetworkPolicies
    privateLinkServiceNetworkPolicies: privateLinkServiceNetworkPolicies
    networkSecurityGroup: empty(nsgId)?null:{
      id: nsgId
    }
  }
}

output id string = subnet.id
