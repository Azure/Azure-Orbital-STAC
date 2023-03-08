// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param environmentCode string
param environmentTag string
param location string
param projectName string
param resourceGroupName string = resourceGroup().name

param keyVaultName string
param keyVaultResourceGroupName string
param logAnalyticsWorkspaceResourceID string
param acrName string = ''
param acrSku string = 'Standard'
param kubernetesVersion string
param storageAccountNameForApim string
param storageAccountResourceGroupName string
param loadBalancerPrivateIP string = '10.6.3.254'
// Roles for APIM and its Managed Identity
param apimMISRoles array = [
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
]

// Parameters for Virtual Network Information
param vnetName string
param vnetResourceGroup string
param vnetSubnetID string

// Parameters for AKS
param aksClusterName string = ''
param aksVmSize string = 'Standard_D2_v5'
param aksUserAgentPools array = [
  {
    name: 'stacpool'
    count: 8
  }
]
param aksNodePoolMaxPods int = 10
param apiManagementServiceName string =''
param apiManagementSku string = 'Premium'
@allowed([
  'None'
  'External'
  'Internal'
])
param apiVirtualNetworkType string = 'External'
param apimSubnetId string = ''
@allowed([
  'stv1'
  'stv2'
])
param apimPlatformVersion string = 'stv2'

// Parameters for jumpbox
param jumpboxVmName string = ''
param jumpboxVmSize string = 'Standard_D2s_v5'

param aksManagedIdentityName string = ''

@description('Type of authentication to use on the Jumpbox Virtual Machine. SSH key is recommended.')
@allowed([
  'sshPublicKey'
  'password'
])
param jumpboxAuthenticationType string = 'password'
param jumpboxAdminUsername string = 'adminuser'
@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param jumpboxAdminPasswordOrKey string
param jumpboxSubnetID string
param jumpboxSshPort int = 22
param userManagedIdentityIdForJumpboxStateCheck string
param azureBastionSubnetID string
param azureBastionName string = ''

var namingPrefix = '${environmentCode}-${projectName}'
var namingSuffix = substring(uniqueString(guid('${subscription().subscriptionId}${namingPrefix}${environmentTag}${location}')), 0, 10)
var acrNameVar = empty(acrName) ? 'acr${namingSuffix}' : acrName
var aksClusterNameVar = empty(aksClusterName) ? 'aks${namingSuffix}' : aksClusterName
var aksManagedIdentityNameVar = empty(aksManagedIdentityName) ? '${namingPrefix}aks-mi' : aksManagedIdentityName
var apiManagementServiceNameVar =  empty(apiManagementServiceName) ? 'apim-${namingSuffix}' : apiManagementServiceName
var jumpboxVmNameVar = empty(jumpboxVmName) ? 'jbox${namingSuffix}' : jumpboxVmName
var jumpboxAdminPasswordOrKeyVar = empty(jumpboxAdminPasswordOrKey) && jumpboxAuthenticationType == 'password' ?'${base64(uniqueString(guid(namingPrefix)))}' : jumpboxAdminPasswordOrKey
var bastionNameVar = empty(azureBastionName)? 'bastion${namingSuffix}' : azureBastionName
var apimStorageAccountBlobServiceUrl = 'https://${storageAccountNameForApim}.blob.${environment().suffixes.storage}'

var apiOperationConfigs = [
  {
    properties: {
      displayName: 'blobStore'
      apiRevision: '1'
      subscriptionRequired: true
      serviceUrl: apimStorageAccountBlobServiceUrl
      path: 'blobstore'
      protocols: [
        'https'
      ]
      isCurrent: true
    }
    policy: {
      value: '''
      <!--
        IMPORTANT:
        - Policy elements can appear only within the <inbound>, <outbound>, <backend> section elements.
        - To apply a policy to the incoming request (before it is forwarded to the backend service), place a corresponding policy element within the <inbound> section element.
        - To apply a policy to the outgoing response (before it is sent back to the caller), place a corresponding policy element within the <outbound> section element.
        - To add a policy, place the cursor at the desired insertion point and select a policy from the sidebar.
        - To remove a policy, delete the corresponding policy statement from the policy document.
        - Position the <base> element within a section element to inherit all policies from the corresponding section element in the enclosing scope.
        - Remove the <base> element to prevent inheriting policies from the corresponding section element in the enclosing scope.
        - Policies are applied in the order of their appearance, from the top down.
        - Comments within policy elements are not supported and may disappear. Place your comments between policy elements or at a higher level scope.
      -->
      <policies>
        <inbound>
          <base />
          <set-header name="x-ms-version" exists-action="override">
            <value>2017-11-09</value>
          </set-header>
          <set-header name="x-ms-blob-type" exists-action="override">
            <value>BlockBlob</value>
          </set-header>
          <authentication-managed-identity resource="https://storage.azure.com" />
        </inbound>
        <backend>
          <base />
        </backend>
        <outbound>
          <base />
        </outbound>
        <on-error>
          <base />
        </on-error>
      </policies>
      '''
      format: 'rawxml'
    }
    operations: [
      {
        name: 'getblob'
        policy: {}
        properties: {
          displayName: 'Get Blob'
          method: 'GET'
          urlTemplate: '/*'
          templateParameters: []
          description: 'getBlob'
          responses: [
            {
              statusCode: 200
            }
          ]
        }
      }
    ]
  }
  {
    properties: {
      displayName: 'fast-stac-api'
      apiRevision: '1'
      subscriptionRequired: false
      serviceUrl: 'http://${loadBalancerPrivateIP}:8082'
      path: 'api'
      protocols: [
        'https'
      ]
      isCurrent: true
    }
    policy: {
      value: '''
      <policies>
        <inbound>
          <base />
          <set-header name="requestURL" exists-action="override">
            <value>@((string)context.Request.OriginalUrl.Path.Trim('/').Substring(context.Api.Path.Trim('/').Length))</value>
          </set-header>
          <set-header name="Accept-Encoding" exists-action="override">
            <value>*</value>
          </set-header>
        </inbound>
        <backend>
          <base />
        </backend>
        <outbound>
          <!-- 
            Rewrite storage account URLs to go through the blobstore proxy.
            This assumes the blob-storage-url named value has been set to the
            blob service endpoint for the storage account.
          -->
          <find-and-replace from="{{blob-storage-url}}" to="@{
              // Get the Gateway URL by taking the scheme/host/port (if non-standard)
              // of the APIM service, but leave off any path and/or query.
              var url = context.Request.OriginalUrl;
              var port = (url.Port == 80 || url.Port == 443) ? "" : (":" + url.Port);
              return url.Scheme + "://" + url.Host + port + "/blobstore";
          }" />
          <!--
              Rewrite any URLs in the body that reference the internal service.
          -->
          <redirect-content-urls />
          <base />
        </outbound>
        <on-error>
          <base />
        </on-error>
      </policies>
      '''
      format: 'rawxml'
    }
    operations: [
      {
        name: 'queryables'
        policy: {}
        properties: {
          displayName: 'Queryables'
          method: 'GET'
          urlTemplate: '/queryables'
          templateParameters: []
          description: 'Queryables'
          responses: []
        }
      }
      {
        name: 'conformance-classes'
        policy: {}
        properties: {
          displayName: 'Conformance'
          method: 'GET'
          urlTemplate: '/conformance'
          templateParameters: []
          responses: []
        }
      }
      {
        name: 'get-search'
        policy: {}
        properties: {
          displayName: 'Search Catalog (GET)'
          method: 'GET'
          urlTemplate: '/search'
          templateParameters: []
          description: '/search'
          responses: [
            {
              statusCode: 200
              representations: [
                {
                  contentType: 'application/json'
                }
              ]
            }
          ]
        }
      }
      {
        name: 'post-search'
        policy: {}
        properties: {
          displayName: 'Search Catalog (POST)'
          method: 'POST'
          urlTemplate: '/search'
          templateParameters: []
          description: '''Cross catalog search (POST).
          Called with `POST /search`.
            Args:
              search_request: search request parameters.
            Returns:
              ItemCollection containing items which match the search criteria.
          '''
          responses: [
            {
              statusCode: 200
            }
          ]
        }
      }
      {
        name: 'get-collections'
        policy: {}
        properties: {
          displayName: 'List Collections'
          method: 'GET'
          urlTemplate: '/collections'
          templateParameters: []
          description: '''Get all collections.
          Called with `GET /collections`.
            Args: 
            Returns:
              Collection.
          '''
          responses: [
            {
              statusCode: 200
            }
          ]
        }
      }
      {
        name: 'get-collection-by-id'
        policy: {}
        properties: {
          displayName: 'Get Collection'
          method: 'GET'
          urlTemplate: '/collections/{collection_id}'
          templateParameters: [
            {
              name: 'collection_id'
              required: true
            }
          ]
          description: '''Get collection by id.
          Called with `GET /collections/{collection_id}`.
            Args:
              collection_id: ID of the collection.
            Returns:
              Collection.
          '''
          responses: [
            {
              statusCode: 200
            }
          ]
        }
      }
      {
        name: 'get-collection-queryables'
        policy: {}
        properties: {
          displayName: 'Collection Queryables'
          method: 'GET'
          urlTemplate: '/collections/{collection_id}/queryables'
          templateParameters: [
            {
              name: 'collection_id'
              required: true
            }
          ]
          description: '''Get collection queryables.
          Called with `GET /collections/{collection_id}/querables`.
            Args:
              collection_id: ID of the collection.
            Returns:
              Qyeryables.
          '''
          responses: [
            {
              statusCode: 200
            }
          ]
        }
      }
      {
        name: 'collections-collection-id-items'
        policy: {}
        properties: {
          displayName: 'List Items in Collection'
          method: 'GET'
          urlTemplate: '/collections/{collection_id}/items'
          templateParameters: [
            {
              name: 'collection_id'
              required: true
            }
          ]
          description: '''Get all items from a specific collection.
          Called with `GET /collections/{collection_id}/items`
            Args:
              collection_id: id of the collection.
              limit: number of items to return.
              token: pagination token.
            Returns:
              An ItemCollection.
          '''
          responses: [
            {
              statusCode: 200
            }
          ]
        }
      }
      {
        name: 'collections-collection-id-items-item-id'
        policy: {}
        properties: {
          displayName: 'Get Item'
          method: 'GET'
          urlTemplate: '/collections/{collection_id}/items/{item_id}'
          templateParameters: [
            {
              name: 'collection_id'
              required: true
            }
            {
              name: 'item_id'
              required: true
            }
          ]
          description: '''Get item by id.
          Called with `GET /collections/{collection_id}/items/{item_id}`.
            Args:
              item_id: ID of the item.
              collection_id: ID of the collection the item is in.
            Returns:
              Item.
          '''
          responses: [
            {
              statusCode: 200
            }
          ]
        }
      }
    ]
  }
]

module acr '../modules/acr.bicep' = {
  name: '${namingPrefix}-acr'
  params: {
    environmentName: environmentTag
    location: location
    acrName: acrNameVar
    acrSku: acrSku
  }
}

module acrCredentials '../modules/acr.credentials.to.keyvault.bicep' = {
  name: '${namingPrefix}-acr-credentials'
  params: {
    environmentName: environmentTag
    acrName: acrNameVar
    keyVaultName: keyVaultName
    keyVaultResourceGroup: keyVaultResourceGroupName
  }
  dependsOn: [
    acr
  ]
}

module aksManagedIdentity '../modules/managed.identity.user.bicep' = {
  name: '${namingPrefix}-aks-managed-identity'
  params: {
    environmentName: environmentTag
    location: location
    uamiName: aksManagedIdentityNameVar
  }
}

module akvPolicyForMI '../modules/akv.policy.bicep' = {
  name: '${namingPrefix}-aks-policy-for-mi'
  scope: resourceGroup(keyVaultResourceGroupName)
  params: {
    keyVaultName: keyVaultName
    policyOps: 'add'
    objIdForPolicy: aksManagedIdentity.outputs.uamiPrincipalId
    secretPermission: [
      'Get'
      'List'
    ]
  }
}

module aksCluster '../modules/aks-cluster.bicep' =  {
  name: '${namingPrefix}-aks'
  params: {
    environmentName: environmentTag
    clusterName: aksClusterNameVar
    location: location
    logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceResourceID
    vmSize: aksVmSize
    networkPlugin: 'kubenet'
    vnetSubnetID: vnetSubnetID
    kubernetesVersion: kubernetesVersion
    clientId: aksManagedIdentity.outputs.uamiClientId
  }
  dependsOn: [
    acr
    aksManagedIdentity
  ]
}

module grantNetworkContributorToAksCluster '../modules/vnet.role-assignment.bicep' = {
  name: '${namingPrefix}-aks-grant-network-contributor-on-vnet'
  scope: resourceGroup(vnetResourceGroup)
  params: {
    vnetName: vnetName
    principalId: aksCluster.outputs.principalId
    // Role definition id maps to 'Network Contributor' role
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7'
  }
}

module grantNetworkResourceGroupReadAccessToAksCluster '../modules/resourcegroup.role-assignment.bicep' = {
  name: '${namingPrefix}-aks-grant-reader-to-vnet-rgp'
  scope: resourceGroup(vnetResourceGroup)
  params: {
    principalId: aksCluster.outputs.principalId
    // Role definition id maps to 'Reader' role
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7'
  }
}
module attachACRtoAKS '../modules/aks-attach-acr.bicep' =  {
  name: '${namingPrefix}-attachACRtoAKS'
  params: {
    kubeletIdentityId: aksCluster.outputs.kubeletIdentityId
    acrName:  acrNameVar
  }
  dependsOn: [
    acr
    aksCluster
  ]
}

module addUserAgentPools '../modules/aks-add-nodepool.bicep' = [ for (config, index) in aksUserAgentPools: {
  name: '${namingPrefix}-addUserAgentPools-${index}'
  params: {
    clusterName: aksClusterNameVar
    agentPoolName: config.name
    count: config.count
    maxPods: aksNodePoolMaxPods
    nodeLable: {
      env: config.name
    }
  }
  dependsOn: [
    aksCluster
  ]
}]

module apim '../modules/apim.bicep' ={
  name : '${namingPrefix}-apim'
  params: {
    apiManagementServiceName: apiManagementServiceNameVar
    publisherEmail: 'admin@${resourceGroupName}.notexist'
    publisherName: resourceGroupName
    sku: apiManagementSku
    location: location
    virtualNetworkType: apiVirtualNetworkType
    subnetId: apimSubnetId
    platformVersion: apimPlatformVersion
  }
}

module apimApis '../modules/apim.api.bicep' = [ for (config, index) in apiOperationConfigs: {
  name: '${namingPrefix}-apim-api-${index}'
  params: {
    parentResourceName: apim.outputs.name
    apiName: config.properties.displayName
    properties: config.properties
    policy: config.policy
  }
  dependsOn: [
    apimMSIStorageRoleAssignment
  ]
}]

module apimApiOperations '../modules/apim.api.operations.bicep' = [ for (config, index) in apiOperationConfigs: {
  name: '${namingPrefix}-apim-api-operations-${index}'
  params: {
    apiManagementName: apim.outputs.name
    apiName: config.properties.displayName
    operations: config.operations
  }
  dependsOn: [
    apimApis
  ]
}]

module apimNamedValues '../modules/apim.namedValues.bicep' = {
  name: '${namingPrefix}-apim-namedValues'
  params: {
    apiManagementServiceName: apim.outputs.name
    name: 'blob-storage-url'
    value: apimStorageAccountBlobServiceUrl
  }
}

module apimMSIStorageRoleAssignment '../modules/storage-role-assignment.bicep' = [ for (role, index) in apimMISRoles: {
  name: '${namingPrefix}-api-storageRole-${index}'
  scope: resourceGroup(storageAccountResourceGroupName)
  params: {
    resourceName: storageAccountNameForApim
    principalId: apim.outputs.principalId
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${role}'
  }
}]

module jumpbox '../modules/virtual-machine.bicep' ={
  name : '${namingPrefix}-jumpbox'
  params: {
    vmName: jumpboxVmNameVar
    location: location
    vmSize: jumpboxVmSize
    adminUsername: jumpboxAdminUsername
    authenticationType: jumpboxAuthenticationType
    adminPasswordOrKey: jumpboxAdminPasswordOrKeyVar
    subnetID: jumpboxSubnetID
    environmentName: environmentTag
    sshPort: jumpboxSshPort
    userManagedIdentityIdForVMStateCheck: userManagedIdentityIdForJumpboxStateCheck
    customData: loadFileAsBase64('./cloud-init-ubuntu.txt')
  }
}

module jumpboxVmCredentials '../modules/vm.credentials.to.keyvault.bicep' = if (empty(jumpboxAdminPasswordOrKey)){
  name: '${namingPrefix}-jumpbox-vm-credentials'
  params: {
    environmentName: environmentTag
    keyVaultName: keyVaultName
    keyVaultResourceGroup: keyVaultResourceGroupName
    vmName: jumpboxVmNameVar
    vmHostname: jumpbox.outputs.hostname
    vmSshPort: string(jumpboxSshPort)
    vmUsername: jumpboxAdminUsername
    vmPassword: (jumpboxAuthenticationType == 'password')?jumpboxAdminPasswordOrKeyVar:'use-ssh-key'
  }
  dependsOn: [
    jumpbox
  ]
}

module azureBastion '../modules/bastion.bicep'= {
  name: '${namingPrefix}-bastion'
  params: {
    location: location
    environmentName: environmentTag
    bastionName: bastionNameVar
    bastionSubnetId: azureBastionSubnetID
  }
  dependsOn: [
    jumpbox
  ]

}
