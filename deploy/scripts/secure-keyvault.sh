#!/usr/bin/env bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

PRJ_ROOT="$(cd `dirname "${BASH_SOURCE}"`/../..; pwd)"
ENV_CODE=${1:-${ENV_CODE}}

if [[ -z "$ENV_CODE" ]]
  then
    echo "Environment Code value not supplied"
    exit 1
fi

set -e

ENV_NAME=${ENV_NAME:-"stac-${ENV_CODE}"}
VNET_RESOURCE_GROUP=${VNET_RESOURCE_GROUP:-"${ENV_CODE}-vnet-rg"}
DATA_RESOURCE_GROUP=${DATA_RESOURCE_GROUP:-"${ENV_CODE}-data-rg"}
VNET_NAME=${VNET_NAME:-"${ENV_CODE}-stac-vnet"}
JUMPBOX_SUBNET_NAME=${JUMPBOX_SUBNET_NAME:-"jumpbox-subnet"}

echo "Getting Jumpbox Subnet ID"
JUMPBOX_SUBNET_ID=$(az network vnet subnet show -g ${VNET_RESOURCE_GROUP} --vnet-name ${VNET_NAME} -n ${JUMPBOX_SUBNET_NAME} -o tsv --query 'id')

echo "Getting Keyvault name"
KEYVAULT_NAME=$(az keyvault list --resource-group ${DATA_RESOURCE_GROUP} --query '[0].name' -o tsv)

echo "Securing Keyvault to be accessed only on jumpbox subnet"
az keyvault network-rule add --name ${KEYVAULT_NAME} --resource-group ${DATA_RESOURCE_GROUP} --subnet ${JUMPBOX_SUBNET_ID}
az keyvault update --name ${KEYVAULT_NAME} --resource-group ${DATA_RESOURCE_GROUP} --set properties.networkAcls.defaultAction=Deny