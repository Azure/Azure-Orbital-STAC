// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

param vmName string
param userManagedIdentityId string
param location string = resourceGroup().location
param randomSuffix string = uniqueString(subscription().id)
param runCounter int = 100
param sleepTimeBetweenExecutions int = 30

module callCLIScript 'cliscript.bicep'= {
  name: 'callCLIScript${randomSuffix}'
  params: {
    userManagedIdentityId: userManagedIdentityId
    location: location
    environmentVariables: [
      {
        name: 'VM_NAME'
        value: vmName
      }
      {
        name: 'RG_NAME'
        value: resourceGroup().name
      }
      {
        name: 'RUN_COUNTER'
        value: runCounter
      }
      {
        name: 'SLEEP_TIME'
        value: sleepTimeBetweenExecutions
      }
    ]
    scriptContent: '''
    VM_STATUS="NA"
    while [ "$VM_STATUS" != "Succeeded" ]; do
    VM_STATUS=$(az vm show -g $RG_NAME -n $VM_NAME  --query 'provisioningState' -o tsv)
      sleep $SLEEP_TIME
      COUNTER=`expr $COUNTER + 1`
      if [ $COUNTER == $RUN_COUNTER ]; then
        break
      fi
    done

    JSON_STRING=$(jq -n \
      --arg vm_status "$VM_STATUS" \
      '{VM_STATUS: $vm_status}' )
    echo $JSON_STRING
    echo $JSON_STRING > $AZ_SCRIPTS_OUTPUT_PATH
    '''
  }
}

output vmSucceeded bool = contains(callCLIScript.outputs.result, 'VM_STATUS') && callCLIScript.outputs.result.VM_STATUS == 'Succeeded'
