#!/usr/bin/env bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

# parameters
ENV_CODE=${1:-${ENV_CODE}}

[[ -z "$ENV_CODE" ]] && { echo "Environment Code value not supplied"; exit 1; }

ENV_TAG=${ENV_TAG:-"stac-${ENV_CODE}"}
DEPLOYMENT_NAME=${DEPLOYMENT_NAME:-"${ENV_TAG}-deploy"}

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
az deployment sub delete --name ${DEPLOYMENT_NAME} --no-wait