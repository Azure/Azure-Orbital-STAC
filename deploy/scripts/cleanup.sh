#!/usr/bin/env bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

# parameters
ENV_CODE=${1:-${ENV_CODE}}

if [[ -z "$ENV_CODE" ]]
  then
    echo "Environment Code value not supplied"
    exit 1
fi

# variables
MONITORING_RESOURCE_GROUP="${ENV_CODE}-monitoring-rg"
VNET_RESOURCE_GROUP="${ENV_CODE}-vnet-rg"
DATA_RESOURCE_GROUP="${ENV_CODE}-data-rg"
PROCESSING_RESOURCE_GROUP="${ENV_CODE}-processing-rg"

set -x
az group delete --name ${MONITORING_RESOURCE_GROUP} --no-wait --yes
az deployment sub delete --name ${MONITORING_RESOURCE_GROUP} --no-wait
az group delete --name ${VNET_RESOURCE_GROUP} --no-wait --yes
az deployment sub delete --name ${VNET_RESOURCE_GROUP} --no-wait
az group delete --name ${DATA_RESOURCE_GROUP} --no-wait --yes
az deployment sub delete --name ${DATA_RESOURCE_GROUP} --no-wait
az group delete --name ${PROCESSING_RESOURCE_GROUP} --no-wait --yes
az deployment sub delete --name ${PROCESSING_RESOURCE_GROUP} --no-wait