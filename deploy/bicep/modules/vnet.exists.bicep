// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param vnetName string
param userManagedIdentityId string
param location string = resourceGroup().location
param utcValue string = utcNow()

module callCLIScript 'cliscript.bicep'= {
  name: 'callCLIScript${utcValue}'
  params: {
    userManagedIdentityId: userManagedIdentityId
    location: location
    environmentVariables: [
      {
        name: 'VNET_NAME'
        value: vnetName
      }
      {
        name: 'RG_NAME'
        value: resourceGroup().name
      }
    ]
    scriptContent: '''
    RESOURCE_ID=$(az network vnet list -g $RG_NAME --query "[?name == '${VNET_NAME}'].id" -otsv 2>/dev/null || echo '')

    JSON_STRING=$(jq -n \
      --arg rid "$RESOURCE_ID" \
      '{RESOURCE_ID: $rid}' )
    echo $JSON_STRING
    echo $JSON_STRING > $AZ_SCRIPTS_OUTPUT_PATH
    '''
  }
}

output vnetExists bool = contains(callCLIScript.outputs.result, 'RESOURCE_ID') && callCLIScript.outputs.result.RESOURCE_ID != ''
