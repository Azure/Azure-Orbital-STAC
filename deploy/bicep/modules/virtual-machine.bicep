// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param environmentName string
param location string = resourceGroup().location

param vmName string
param vmSize string

@description('Type of authentication to use on the Virtual Machine. SSH key is recommended.')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string = 'password'
param adminUsername string = 'adminuser'
@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param adminPasswordOrKey string
param customData string = ''
var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}

param subnetID string

var osDiskType = 'Standard_LRS'
param vmImagePublisher string = 'Canonical'
param vmImageOffer string = '0001-com-ubuntu-server-focal'
param vmImageSku string = '20_04-lts-gen2'
param vmImageVersion string = 'latest'

param securityGroupName string = '${vmName}SSH'
param networkInterfaceName string  = '${vmName}NetInt'
param publicIPAddressName string = '${vmName}PublicIP'
param dnsLabelPrefix string = toLower('${vmName}-${uniqueString(resourceGroup().id)}')
param enablePublicAccess bool = false

param sshPort int = 22

param utcValue string = utcNow()

param userManagedIdentityIdForVMStateCheck string

var stringSshPort = string(sshPort)
var sshCommand = 'sudo sed -i -e "s|^#Port 22|Port ${stringSshPort}|" /etc/ssh/sshd_config && sudo service ssh restart'

module publicIP './publicip.bicep' = if (enablePublicAccess) {
  name: publicIPAddressName
  params: {
    name: publicIPAddressName
    location: location
    dnsLabelPrefix: dnsLabelPrefix
  }

}
resource nsg 'Microsoft.Network/networkSecurityGroups@2022-01-01' = if (enablePublicAccess) {
  name: securityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: string(sshPort)
        }
      }
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2022-01-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetID

          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: enablePublicAccess ? { id: publicIP.outputs.id } : null
        }
      }
    ]
    networkSecurityGroup: enablePublicAccess ? { id: nsg.id }: null
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: vmName
  location: location
  tags: {
    environment: environmentName
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      imageReference: {
        publisher: vmImagePublisher
        offer: vmImageOffer
        sku: vmImageSku
        version: vmImageVersion
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      customData: empty(customData)? null: customData
      linuxConfiguration: ((authenticationType == 'password') ? null : linuxConfiguration)
    }
  }
}

module checkVmProvisioningState '../modules/vm.check.provisioningstate.bicep' = {
  name : '${vmName}-checkVmProvisioningState-${utcValue}'
  params: {
    userManagedIdentityId: userManagedIdentityIdForVMStateCheck
    vmName: vmName
    location: location
  }
  dependsOn: [
    vm
  ]
}

module jumpboxSshAccess '../modules/vm.run-command.bicep' = if (sshPort != 22) {
  name : '${vmName}-ssh-access'
  params: {
    environmentName: environmentName
    vmName: vmName
    runCommandName: '${vmName}-grant-ssh-access-command-${utcValue}'
    location: location
    script: checkVmProvisioningState.outputs.vmSucceeded?sshCommand:'vm-did-not-work'
    runAsUser: 'root'
  }
  dependsOn: enablePublicAccess? [
    nsg
    vm
    checkVmProvisioningState
  ]: [
    vm
    checkVmProvisioningState
  ]
}

output adminUsername string = adminUsername
output hostname string = enablePublicAccess ? publicIP.outputs.hostname : nic.properties.ipConfigurations[0].properties.privateIPAddress
