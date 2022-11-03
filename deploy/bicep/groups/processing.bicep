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
param apiManagementServiceName string =''
param apiManagementSku string = 'Premium'
@allowed([
  'None'
  'External'
  'Internal'
])
param apiVirtualNetworkType string = 'External'
param apimSubnetId string = ''

// Parameters for jumpbox
param jumpboxVmName string = ''
param jumpboxVmSize string = 'Standard_D2s_v5'

param configurePodIdentity bool = false
param podIdentityMiName string = ''

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
var podIdentityMiNameVar = empty(podIdentityMiName) ? '${namingPrefix}aks-pod-identity-mi' : podIdentityMiName
var apiManagementServiceNameVar =  empty(apiManagementServiceName) ? 'apim-${namingSuffix}' : apiManagementServiceName
var jumpboxVmNameVar = empty(jumpboxVmName) ? 'jbox${namingSuffix}' : jumpboxVmName
var jumpboxAdminPasswordOrKeyVar = empty(jumpboxAdminPasswordOrKey) && jumpboxAuthenticationType == 'password' ?'${base64(uniqueString(guid(namingPrefix)))}' : jumpboxAdminPasswordOrKey
var bastionNameVar = empty(azureBastionName)? 'bastion${namingSuffix}' : azureBastionName

var apiOperationConfigs = [
  {
    properties: {
      displayName: 'blobStore'
      apiRevision: '1'
      subscriptionRequired: true
      serviceUrl: 'https://${storageAccountNameForApim}.blob.${environment().suffixes.storage}'
      path: 'blobstore'
      protocols: [
        'https'
      ]
      isCurrent: true
    }
    policy: {
      value: '<!--\r\n    IMPORTANT:\r\n    - Policy elements can appear only within the <inbound>, <outbound>, <backend> section elements.\r\n    - To apply a policy to the incoming request (before it is forwarded to the backend service), place a corresponding policy element within the <inbound> section element.\r\n    - To apply a policy to the outgoing response (before it is sent back to the caller), place a corresponding policy element within the <outbound> section element.\r\n    - To add a policy, place the cursor at the desired insertion point and select a policy from the sidebar.\r\n    - To remove a policy, delete the corresponding policy statement from the policy document.\r\n    - Position the <base> element within a section element to inherit all policies from the corresponding section element in the enclosing scope.\r\n    - Remove the <base> element to prevent inheriting policies from the corresponding section element in the enclosing scope.\r\n    - Policies are applied in the order of their appearance, from the top down.\r\n    - Comments within policy elements are not supported and may disappear. Place your comments between policy elements or at a higher level scope.\r\n-->\r\n<policies>\r\n  <inbound>\r\n    <base />\r\n    <set-header name="x-ms-version" exists-action="override">\r\n      <value>2017-11-09</value>\r\n    </set-header>\r\n    <set-header name="x-ms-blob-type" exists-action="override">\r\n      <value>BlockBlob</value>\r\n    </set-header>\r\n    <authentication-managed-identity resource="https://storage.azure.com" />\r\n  </inbound>\r\n  <backend>\r\n    <base />\r\n  </backend>\r\n  <outbound>\r\n    <base />\r\n  </outbound>\r\n  <on-error>\r\n    <base />\r\n  </on-error>\r\n</policies>'
      format: 'xml'
    }
    operations: [
      {
        name: 'get-blob'
        policy: {}
        properties: {
          displayName: 'get blob'
          method: 'GET'
          urlTemplate: '/'
          templateParameters: []
          description: 'get blob'
          responses: [
            {
              statusCode: 200
              description: 'null'
              representations: []
              headers: []
            }
          ]
        }
      }
      {
        name: 'getblob'
        policy: {}
        properties: {
          displayName: 'getBlob'
          method: 'GET'
          urlTemplate: '/{container}/{blob}'
          templateParameters: [
            {
              name: 'container'
              required: true
              values: []
              typeName: 'container-blob-GetRequest'
            }
            {
              name: 'blob'
              required: true
              values: []
              typeName: 'container-blob-GetRequest-1'
            }
          ]
          description: 'getBlob'
          responses: [
            {
              statusCode: 200
              description: 'null'
              representations: []
              headers: []
            }
          ]
        }
      }
      {
        name: 'redirect-blob'
        policy: {}
        properties: {
          displayName: 'redirect blob'
          method: 'GET'
          urlTemplate: '/redirectblob'
          templateParameters: []
          description: 'redirect-blob'
          responses: [
            {
              statusCode: 200
              description: 'null'
              representations: []
              headers: []
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
      value: '<policies>\r\n  <inbound>\r\n    <base />\r\n    <set-header name="requestURL" exists-action="override">\r\n      <value>@((string)context.Request.OriginalUrl.Path.Trim(\'/\').Substring(context.Api.Path.Trim(\'/\').Length))</value>\r\n    </set-header>\r\n    <set-header name="Accept-Encoding" exists-action="override">\r\n      <value>*</value>\r\n    </set-header>\r\n  </inbound>\r\n  <backend>\r\n    <base />\r\n  </backend>\r\n  <outbound>\r\n    <base />\r\n  </outbound>\r\n  <on-error>\r\n    <base />\r\n  </on-error>\r\n</policies>'
      format: 'xml'
    }
    operations: [
      {
        name: 'queryables'
        policy: {}
        properties: {
          displayName: '/queryables'
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
          displayName: '/conformance'
          method: 'GET'
          urlTemplate: '/conformance'
          templateParameters: []
          responses: []
        }
      }
      {
        name: 'get-search'
        policy: {
          value: '<!--\r\nfast-stac-api: /search\r\n-->\r\n<policies>\r\n  <inbound>\r\n    <base />\r\n  </inbound>\r\n  <backend>\r\n    <base />\r\n  </backend>\r\n  <outbound>\r\n    <choose>\r\n      <when condition="@(context.Response.StatusCode == 200)">\r\n        <return-response>\r\n          <set-header name="Content-Type" exists-action="override">\r\n            <value>application/geo+json</value>\r\n          </set-header>\r\n          <set-header name="Accept" exists-action="override">\r\n            <value>application/geo+json</value>\r\n          </set-header>\r\n          <set-body>@{\r\n                        try\r\n                            {\r\n                            JObject body = null;\r\n                            var str = "";\r\n                            var apimURL = context.Api.ServiceUrl.ToString().LastIndexOf("/") == -1 ?\r\n                            context.Api.ServiceUrl.ToString() : context.Api.ServiceUrl.ToString().Substring(0,\r\n                            context.Api.ServiceUrl.ToString().LastIndexOf("/"));\r\n                            var name = context.Request.OriginalUrl.ToString();\r\n                            Uri nameURI = new Uri(name);\r\n                            string originalURL = "https://" + nameURI.Authority;\r\n                            string blobStoreName = "blobstore";\r\n                            string blobStoreRoute = "/redirectblob";\r\n  \r\n                                body = context.Response.Body.As&lt;JObject&gt;(preserveContent: true);\r\n\r\n                                foreach (var item in body["features"])\r\n                                {\r\n\r\n                                    if(item.SelectToken("assets.visual.href") != null)\r\n                                    {\r\n                                        try\r\n                                        {\r\n                                            Uri assetUri = new Uri(item["assets"]["visual"]["href"].ToString());\r\n                                            item["assets"]["visual"]["href"] =  originalURL + "/" + blobStoreName + blobStoreRoute + "?path=" + assetUri.AbsolutePath;\r\n                                        }\r\n                                        catch (System.Exception)\r\n                                        {\r\n                                            // Do nothing\r\n                                        }\r\n                                    }\r\n\r\n                                    if(item.SelectToken("assets.image.href") != null)\r\n                                    {\r\n                                        Uri assetUri = new Uri(item["assets"]["image"]["href"].ToString());\r\n                                        item["assets"]["image"]["href"] = originalURL + "/" + blobStoreName + blobStoreRoute + "?path="\r\n                                        + assetUri.AbsolutePath;\r\n                                    }\r\n\r\n\r\n                                    if(item.SelectToken("assets.thumbnail.href") != null)\r\n                                    {\r\n                                        Uri assetUri = new Uri(item["assets"]["thumbnail"]["href"].ToString());\r\n                                        item["assets"]["thumbnail"]["href"] = originalURL + "/" + blobStoreName + blobStoreRoute + "?path="\r\n                                        + assetUri.AbsolutePath;\r\n                                    }\r\n\r\n\r\n\r\n                                     if(item.SelectToken("assets.metadata.href") != null) \r\n                                     {\r\n                                        Uri metadataUri = new Uri(item["assets"]["metadata"]["href"].ToString());\r\n                                        item["assets"]["metadata"]["href"] = originalURL + "/" + blobStoreName + blobStoreRoute +\r\n                                        "?path="\r\n                                        + metadataUri.AbsolutePath;\r\n                                     }\r\n                                }\r\n\r\n                                return body.ToString();\r\n                            }\r\n                             catch (Exception e) {\r\n                            return context.Response.Body.As&lt;string&gt;(preserveContent: true);\r\n                        }\r\n                        }</set-body>\r\n        </return-response>\r\n      </when>\r\n    </choose>\r\n    <base />\r\n  </outbound>\r\n  <on-error>\r\n    <base />\r\n  </on-error>\r\n</policies>'
          format: 'xml'
        }
        properties: {
          displayName: '/search'
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
                  examples: {
                    default: {
                      value: {
                      }
                    }
                  }
                  typeName: 'getsearch'
                }
              ]
              headers: []
            }
          ]
        }
      }
      {
        name: 'post-search'
        policy: {}
        properties: {
          displayName: '/search'
          method: 'POST'
          urlTemplate: '/search'
          templateParameters: []
          description: '        """Cross catalog search (POST).\n\n        Called with `POST /search`.\n\n        Args:\n            search_request: search request parameters.\n\n        Returns:\n            ItemCollection containing items which match the search criteria.\n        """'
          responses: [
            {
              statusCode: 200
              description: 'null'
              representations: []
              headers: []
            }
          ]
        }
      }
      {
        name: 'get-collection-by-id'
        policy: {}
        properties: {
          displayName: '/collections/{collection_id}'
          method: 'GET'
          urlTemplate: '/collections/{collection_id}'
          templateParameters: [
            {
              name: 'collection_id'
              required: true
              values: []
              typeName: 'Collections-collection_id-GetRequest'
            }
          ]
          description: 'Get collection by id.\nCalled with `GET /collections/{collection_id}`.\nArgs: collection_id: ID of the collection.\nReturns:  Collection.'
          responses: [
            {
              statusCode: 200
              description: 'null'
              representations: []
              headers: []
            }
          ]
        }
      }
      {
        name: 'collections-collection-id-items'
        policy: {
          value: '<!--\r\nfast-stac-api: /collections/{collection_id}/items\r\n-->\r\n<policies>\r\n  <inbound>\r\n    <base />\r\n  </inbound>\r\n  <backend>\r\n    <base />\r\n  </backend>\r\n  <outbound>\r\n    <choose>\r\n      <when condition="@(context.Response.StatusCode == 200)">\r\n        <return-response>\r\n          <set-header name="Content-Type" exists-action="override">\r\n            <value>application/geo+json</value>\r\n          </set-header>\r\n          <set-header name="Accept" exists-action="override">\r\n            <value>application/geo+json</value>\r\n          </set-header>\r\n          <set-body>@{\r\n                        try\r\n                            {\r\n                            JObject body = null;\r\n                            var str = "";\r\n                            var apimURL = context.Api.ServiceUrl.ToString().LastIndexOf("/") == -1 ?\r\n                            context.Api.ServiceUrl.ToString() : context.Api.ServiceUrl.ToString().Substring(0,\r\n                            context.Api.ServiceUrl.ToString().LastIndexOf("/"));\r\n                            var name = context.Request.OriginalUrl.ToString();\r\n                            Uri nameURI = new Uri(name);\r\n                            string originalURL = "https://" + nameURI.Authority;\r\n                            string blobStoreName = "blobstore";\r\n                            string blobStoreRoute = "/redirectblob";\r\n  \r\n                                body = context.Response.Body.As&lt;JObject&gt;(preserveContent: true);\r\n\r\n                                foreach (var item in body["features"])\r\n                                {\r\n\r\n                                    if(item.SelectToken("assets.visual.href") != null)\r\n                                    {\r\n                                        try\r\n                                        {\r\n                                            Uri assetUri = new Uri(item["assets"]["visual"]["href"].ToString());\r\n                                            item["assets"]["visual"]["href"] =  originalURL + "/" + blobStoreName + blobStoreRoute + "?path=" + assetUri.AbsolutePath;\r\n                                        }\r\n                                        catch (System.Exception)\r\n                                        {\r\n                                            // Do nothing\r\n                                        }\r\n                                    }\r\n\r\n                                    if(item.SelectToken("assets.image.href") != null)\r\n                                    {\r\n                                        Uri assetUri = new Uri(item["assets"]["image"]["href"].ToString());\r\n                                        item["assets"]["image"]["href"] = originalURL + "/" + blobStoreName + blobStoreRoute + "?path="\r\n                                        + assetUri.AbsolutePath;\r\n                                    }\r\n\r\n\r\n                                    if(item.SelectToken("assets.thumbnail.href") != null)\r\n                                    {\r\n                                        Uri assetUri = new Uri(item["assets"]["thumbnail"]["href"].ToString());\r\n                                        item["assets"]["thumbnail"]["href"] = originalURL + "/" + blobStoreName + blobStoreRoute + "?path="\r\n                                        + assetUri.AbsolutePath;\r\n                                    }\r\n\r\n\r\n\r\n                                     if(item.SelectToken("assets.metadata.href") != null) \r\n                                     {\r\n                                        Uri metadataUri = new Uri(item["assets"]["metadata"]["href"].ToString());\r\n                                        item["assets"]["metadata"]["href"] = originalURL + "/" + blobStoreName + blobStoreRoute +\r\n                                        "?path="\r\n                                        + metadataUri.AbsolutePath;\r\n                                     }\r\n                                }\r\n\r\n                                return body.ToString();\r\n                            }\r\n                             catch (Exception e) {\r\n                            return context.Response.Body.As&lt;string&gt;(preserveContent: true);\r\n                        }\r\n                        }</set-body>\r\n        </return-response>\r\n      </when>\r\n    </choose>\r\n    <base />\r\n  </outbound>\r\n  <on-error>\r\n    <base />\r\n  </on-error>\r\n</policies>'
          format: 'xml'
        }
        properties: {
          displayName: '/collections/{collection_id}/items'
          method: 'GET'
          urlTemplate: '/collections/{collection_id}/items'
          templateParameters: [
            {
              name: 'collection_id'
              required: true
              values: []
              typeName: 'Collections-collection_id-ItemsGetRequest'
            }
          ]
          description: '        """Get all items from a specific collection.\n\n        Called with `GET /collections/{collection_id}/items`\n\n        Args:\n            collection_id: id of the collection.\n            limit: number of items to return.\n            token: pagination token.\n\n        Returns:\n            An ItemCollection.\n        """'
          responses: [
            {
              statusCode: 200
              description: 'null'
              representations: []
              headers: []
            }
          ]
        }
      }
      {
        name: 'collections-collection-id-items-item-id'
        policy: {
          value: '<!--\r\nfast-stac-api: /collections/{collection_id}/items/{item_id}\r\n-->\r\n<policies>\r\n  <inbound>\r\n    <base />\r\n  </inbound>\r\n  <backend>\r\n    <base />\r\n  </backend>\r\n  <outbound>\r\n    <choose>\r\n      <when condition="@(context.Response.StatusCode == 200)">\r\n        <return-response>\r\n          <set-header name="Content-Type" exists-action="override">\r\n            <value>application/geo+json</value>\r\n          </set-header>\r\n          <set-header name="Accept" exists-action="override">\r\n            <value>application/geo+json</value>\r\n          </set-header>\r\n          <set-body>@{\r\n                            var body = context.Response.Body.As&lt;string&gt;(preserveContent: true);\r\n                            var str = "";\r\n                            var apimURL = context.Api.ServiceUrl.ToString().LastIndexOf("/") == -1 ?\r\n                            context.Api.ServiceUrl.ToString() : context.Api.ServiceUrl.ToString().Substring(0,\r\n                            context.Api.ServiceUrl.ToString().LastIndexOf("/"));\r\n                            var name = context.Request.OriginalUrl.ToString();\r\n                            Uri nameURI = new Uri(name);\r\n                            string originalURL = "https://" + nameURI.Authority;\r\n                            string blobStoreName = "blobstore";\r\n                            string blobStoreRoute = "/redirectblob";\r\n                            JObject jsonObject = JObject.Parse(body);\r\n\r\n                            foreach (var item in jsonObject)\r\n                            {\r\n                               if(item.Key == "assets") {\r\n\r\n                                    if(jsonObject.SelectToken("assets.visual.href") != null) {\r\n                                        Uri assetUri = new Uri(jsonObject["assets"]["visual"]["href"].ToString());\r\n                                        jsonObject["assets"]["visual"]["href"] =  originalURL + "/" + blobStoreName + blobStoreRoute + "?path=" + assetUri.AbsolutePath;\r\n                                    }\r\n\r\n                                    if(jsonObject.SelectToken("assets.image.href") != null) {\r\n                                        Uri assetUri = new Uri(jsonObject["assets"]["image"]["href"].ToString());\r\n                                        jsonObject["assets"]["image"]["href"] = originalURL + "/" + blobStoreName + blobStoreRoute + "?path="\r\n                                        + assetUri.AbsolutePath;\r\n                                    }\r\n\r\n\r\n                                    if(jsonObject.SelectToken("assets.thumbnail.href") != null) {\r\n                                        Uri thumbnailUri = new Uri(jsonObject["assets"]["thumbnail"]["href"].ToString());\r\n                                        jsonObject["assets"]["thumbnail"]["href"] = originalURL + "/" + blobStoreName + blobStoreRoute +\r\n                                        "?path=" + thumbnailUri.AbsolutePath;\r\n                                    }\r\n\r\n                                    if(jsonObject.SelectToken("assets.metadata.href") != null) {\r\n                                        Uri metadataUri = new Uri(jsonObject["assets"]["metadata"]["href"].ToString());\r\n                                        jsonObject["assets"]["metadata"]["href"] = originalURL + "/" + blobStoreName + blobStoreRoute +\r\n                                        "?path=" + metadataUri.AbsolutePath;\r\n                                    }\r\n                               }\r\n                            }\r\n                            return jsonObject.ToString();\r\n                        }</set-body>\r\n        </return-response>\r\n      </when>\r\n    </choose>\r\n    <base />\r\n  </outbound>\r\n  <on-error>\r\n    <base />\r\n  </on-error>\r\n</policies>'
          format: 'xml'
        }
        properties: {
          displayName: '/collections/{collection_id}/items/{item_id}'
          method: 'GET'
          urlTemplate: '/collections/{collection_id}/items/{item_id}'
          templateParameters: [
            {
              name: 'collection_id'
              required: true
              values: []
              typeName: 'Collections-collection_id-Items-item_id-GetRequest'
            }
            {
              name: 'item_id'
              required: true
              values: []
              typeName: 'Collections-collection_id-Items-item_id-GetRequest-1'
            }
          ]
          description: '        """Get item by id.\n\n        Called with `GET /collections/{collection_id}/items/{item_id}`.\n\n        Args:\n            item_id: ID of the item.\n            collection_id: ID of the collection the item is in.\n\n        Returns:\n            Item.\n        """'
          responses: [
            {
              statusCode: 200
              description: 'null'
              representations: []
              headers: []
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

module podIdentityManagedIdentity '../modules/managed.identity.user.bicep' = if (configurePodIdentity) {
  name: '${namingPrefix}-aks-pod-identity'
  params: {
    environmentName: environmentTag
    location: location
    uamiName: podIdentityMiNameVar
  }
}

module aksCluster '../modules/aks-cluster-with-pod-identity.bicep' =  {
  name: '${namingPrefix}-aks'
  params: {
    environmentName: environmentTag
    clusterName: aksClusterNameVar
    location: location
    logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceResourceID
    vmSize: aksVmSize
    networkPlugin: 'kubenet'
    vnetSubnetID: vnetSubnetID
    managedIdentityName: configurePodIdentity?podIdentityMiNameVar:''
    managedIdentityResourcegroupName: configurePodIdentity?resourceGroupName:''
    managedIdentityId: configurePodIdentity?podIdentityManagedIdentity.outputs.uamiId:''
    managedIdentityClientId: configurePodIdentity?podIdentityManagedIdentity.outputs.uamiClientId:''
    managedIdentityPrincipalId: configurePodIdentity?podIdentityManagedIdentity.outputs.uamiPrincipalId:''
  }
  dependsOn: [
    acr
    podIdentityManagedIdentity
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
  }
}

module apimApis '../modules/apim.api.bicep' = [ for (config, index) in apiOperationConfigs: {
  name: '${namingPrefix}-apim-api-${index}'
  params: {
    parentResourceName: apiManagementServiceNameVar
    apiName: config.properties.displayName
    properties: config.properties
    policy: config.policy
  }
  dependsOn: [
    apim
    apimMSIStorageRoleAssignment
  ]
}]

module apimApiOperations '../modules/apim.api.operations.bicep' = [ for (config, index) in apiOperationConfigs: {
  name: '${namingPrefix}-apim-api-operations-${index}'
  params: {
    apiManagementName: apiManagementServiceNameVar
    apiName: config.properties.displayName
    operations: config.operations
  }
  dependsOn: [
    apimApis
  ]
}]
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
