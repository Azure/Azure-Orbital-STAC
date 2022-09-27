// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

// List of required parameters
param environmentCode string
param environmentTag string
param projectName string
param location string
param virtualNetworkName string

// Parameters with default values for Virtual Network
@allowed([
  'new'
  'existing'
])
param newOrExisting string = 'new'
param vnetAddressPrefix string = '10.6.0.0/16'
param jumpboxSubnetAddressPrefix string = '10.6.0.0/24'
param pgDelegatedSubnetAddressPrefix string = '10.6.1.0/24'
param dataSubnetAddressPrefix string = '10.6.2.0/24'
param aksSubnetAddressPrefix string = '10.6.3.0/24'
param apimSubnetAddressPrefix string = '10.6.4.0/24'
param bastionSubnetAddressPrefix string = '10.6.250.0/24'
param pgPrivateDNSZoneName string = 'privatelink.postgres.database.azure.com'
param blobPrivateDNSZoneName string =''

var blobPrivateDNSZoneNameVar = empty(blobPrivateDNSZoneName) ? 'privatelink.blob.${environment().suffixes.storage}' : blobPrivateDNSZoneName
var namingPrefix = '${environmentCode}-${projectName}'
var vnetLinkName = uniqueString(namingPrefix)
var privateDnsZoneConfig = [
  {
    zoneName: pgPrivateDNSZoneName
  }
  {
    zoneName: blobPrivateDNSZoneNameVar
  }
]

var aksSecurityGroupRules = [ {
  name: 'Allow_APIM_to_K8S'
  properties: {
    access: 'Allow'
    description: 'Allow APIM to K8S traffic'
    destinationAddressPrefix: '*'
    destinationPortRange: '8082'
    direction: 'Inbound'
    priority: 100
    protocol: 'TCP'
    sourceAddressPrefix: '*'
    sourcePortRange: '*'
  }
} 
]

module apimSecurityGroup '../modules/apim.security-group.bicep' = if(newOrExisting == 'new') {
  name: '${namingPrefix}-apim-security-group'
  params: {
    location: location
  }
}

module jumpboxSubnetOverrideSecurityGroup '../modules/security-group.bicep' = if(newOrExisting == 'new') {
  name: '${namingPrefix}-jumpbox-subnet-overide-security-group'
  params: {
    name: '${namingPrefix}-jumpbox-subnet-overide-security-group'
    location: location
  }
}

module pgDelegatedSubnetOverrideSecurityGroup '../modules/security-group.bicep' = if(newOrExisting == 'new') {
  name: '${namingPrefix}-pg-subnet-overide-security-group'
  params: {
    name: '${namingPrefix}-pg-subnet-overide-security-group'
    location: location
  }
}

module dataSubnetOverrideSecurityGroup '../modules/security-group.bicep' = if(newOrExisting == 'new') {
  name: '${namingPrefix}-data-subnet-overide-security-group'
  params: {
    name: '${namingPrefix}-data-subnet-overide-security-group'
    location: location
  }
}

module aksSubnetOverrideSecurityGroup '../modules/security-group.bicep' = if(newOrExisting == 'new') {
  name: '${namingPrefix}-aks-subnet-overide-security-group'
  params: {
    name: '${namingPrefix}-aks-subnet-overide-security-group'
    location: location
    securityRules: aksSecurityGroupRules
  }
}

module bastionSubnetOverrideSecurityGroup '../modules/bastion-security-group.bicep' = if(newOrExisting == 'new') {
  name: '${namingPrefix}-bastion-subnet-overide-security-group'
  params: {
    bastionName: '${namingPrefix}-bastion-subnet-overide-security-group'
    location: location
  }
}

module vnet '../modules/vnet.bicep' = if (newOrExisting == 'new') {
  name: '${namingPrefix}-vnet'
  params: {
    environmentName: environmentTag
    virtualNetworkName: virtualNetworkName
    location: location
    addressPrefix: vnetAddressPrefix
  }
  dependsOn:[
    apimSecurityGroup
    jumpboxSubnetOverrideSecurityGroup
    dataSubnetOverrideSecurityGroup
    pgDelegatedSubnetOverrideSecurityGroup
    aksSubnetOverrideSecurityGroup
    bastionSubnetOverrideSecurityGroup
  ]
}

module jumpboxSubnet '../modules/subnet.bicep' = if(newOrExisting == 'new') {
  name: '${namingPrefix}-jumpbox-subnet'
  params: {
    vNetName: virtualNetworkName
    subnetName: 'jumpbox-subnet'
    subnetAddressPrefix: jumpboxSubnetAddressPrefix
    serviceEndPoints:[
      {
        locations: [location]
        service: 'Microsoft.ServiceBus'
      }
      {
        locations: [location]
        service: 'Microsoft.KeyVault'
      }

    ]
    nsgId: jumpboxSubnetOverrideSecurityGroup.outputs.id
  }
  dependsOn: [
    vnet
    jumpboxSubnetOverrideSecurityGroup
  ]
}

module pgDelegatedSubnet '../modules/subnet.bicep' = if (newOrExisting == 'new') {
  name: '${namingPrefix}-pg-delegated-subnet'
  params: {
    vNetName: virtualNetworkName
    subnetName: 'pg-subnet'
    subnetAddressPrefix: pgDelegatedSubnetAddressPrefix
    delegations: [
      {
        name: 'dlg-Microsoft.DBforPostgreSQL-flexibleServers'
        properties: {
          serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
        }
      }
    ]
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    nsgId: pgDelegatedSubnetOverrideSecurityGroup.outputs.id
  }
  dependsOn: [
    vnet
    jumpboxSubnet
    pgDelegatedSubnetOverrideSecurityGroup
  ]
}

module dataSubnet '../modules/subnet.bicep' = if (newOrExisting == 'new') {
  name: '${namingPrefix}-data-subnet'
  params: {
    vNetName: virtualNetworkName
    subnetName: 'data-subnet'
    subnetAddressPrefix: dataSubnetAddressPrefix
    serviceEndPoints:[
      {
        locations: [location]
        service: 'Microsoft.ServiceBus'
      }
    ]
    nsgId: dataSubnetOverrideSecurityGroup.outputs.id
  }
  dependsOn: [
    vnet
    jumpboxSubnet
    pgDelegatedSubnet
    dataSubnetOverrideSecurityGroup
  ]
}

module aksSubnet '../modules/subnet.bicep' = if(newOrExisting == 'new') {
  name: '${namingPrefix}-aks-subnet'
  params: {
    vNetName: virtualNetworkName
    subnetName: 'aks-subnet'
    subnetAddressPrefix: aksSubnetAddressPrefix
    serviceEndPoints:[
      {
        locations: [location]
        service: 'Microsoft.ServiceBus'
      }
    ]
    nsgId: aksSubnetOverrideSecurityGroup.outputs.id
  }
  dependsOn: [
    vnet
    jumpboxSubnet
    pgDelegatedSubnet
    dataSubnet
    aksSubnetOverrideSecurityGroup
  ]
}

module apimSubnet '../modules/subnet.bicep' = if (newOrExisting == 'new') {
  name: '${namingPrefix}-apim-subnet'
  params: {
    vNetName: virtualNetworkName
    subnetName: 'apim-subnet'
    subnetAddressPrefix: apimSubnetAddressPrefix
    serviceEndPoints:[
      {
        locations: [location]
        service: 'Microsoft.Storage'
      }
    ]
    nsgId: apimSecurityGroup.outputs.id
  }
  dependsOn: [
    vnet
    jumpboxSubnet
    pgDelegatedSubnet
    dataSubnet
    aksSubnet
    apimSecurityGroup
  ]
}

module bastionSubnet '../modules/subnet.bicep' = if (newOrExisting == 'new') {
  name: '${namingPrefix}-bastion-subnet'
  params: {
    vNetName: virtualNetworkName
    subnetName: 'AzureBastionSubnet' // The Bastion Subnet is required to be named AzureBastionSubnet
    subnetAddressPrefix: bastionSubnetAddressPrefix
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
    nsgId: bastionSubnetOverrideSecurityGroup.outputs.id
  }
  dependsOn: [
    vnet
    jumpboxSubnet
    pgDelegatedSubnet
    dataSubnet
    aksSubnet
    apimSecurityGroup
    apimSubnet
    bastionSubnetOverrideSecurityGroup
  ]
}

module privateDNSZones '../modules/private-dns-zone.bicep' = [for (conf, index) in privateDnsZoneConfig: if (newOrExisting == 'new') {
  name: '${namingPrefix}-private-dns-zone-${index}'
  params: {
    privateDnsZoneName: conf.zoneName
  }
  dependsOn: [
    vnet
    jumpboxSubnet
    pgDelegatedSubnet
    dataSubnet
    aksSubnet
    apimSecurityGroup
    apimSubnet
    bastionSubnet
  ]
}]

module privateDNSZoneVirtualLinks '../modules/private-dns-zone.vnetlink.bicep' = [for (conf, index) in privateDnsZoneConfig: if (newOrExisting == 'new') {
  name: '${namingPrefix}-private-dns-zone-virtual-link-${index}'
  params: {
    privateDnsZoneName: conf.zoneName
    customVnetId: (newOrExisting == 'new') ? vnet.outputs.id : ''
    vnetLinkName: vnetLinkName
  }
  dependsOn: [
    vnet
    jumpboxSubnet
    pgDelegatedSubnet
    dataSubnet
    aksSubnet
    apimSecurityGroup
    apimSubnet
    bastionSubnet
    privateDNSZones
  ]
}]

output vnetId string = vnet.outputs.id
output jumpboxSubnetId string = jumpboxSubnet.outputs.id
output pgDelegatedSubnetId string = pgDelegatedSubnet.outputs.id
output dataSubnetId string = dataSubnet.outputs.id
output aksSubnetId string = aksSubnet.outputs.id
output apimSubnetId string = apimSubnet.outputs.id
output bastionSubnetId string = bastionSubnet.outputs.id
output serviceBusAccessingSubnetsList array = [aksSubnet.outputs.id, dataSubnet.outputs.id, jumpboxSubnet.outputs.id]
output pgPrivateDNSZoneName string = pgPrivateDNSZoneName
output pgPrivateDNSZoneId string = privateDNSZones[0].outputs.id
output pgPrivateDnsZoneVirtualLinkId string = privateDNSZoneVirtualLinks[0].outputs.id
output storageAccountPrivateDNSZoneName string = blobPrivateDNSZoneNameVar
output storageAccountPrivateDNSZoneId string = privateDNSZones[1].outputs.id
output storageAccountPrivateDnsZoneVirtualLinkId string = privateDNSZoneVirtualLinks[1].outputs.id
