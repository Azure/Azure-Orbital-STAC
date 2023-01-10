#!/usr/bin/env bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

set -ex
PRJ_ROOT="$(cd `dirname "${BASH_SOURCE}"`/../..; pwd)"


if [[ -z "$1" ]]
  then
    echo "Environment Code value not supplied"
    exit 1
fi

if [[ -z "$2" ]]
  then
    echo "Location value not supplied"
    exit 1
fi

if [[ -z "$3" ]]
  then
    echo "Jumpbox Password not supplied"
    exit 1
fi

# Setup parameters
ENV_CODE=${1:-${ENV_CODE}}
LOCATION=${2:-${LOCATION}}
JUMPBOX_PASSWORD=${3:-${JUMPBOX_PASSWORD}}
JUMPBOX_USERNAME=${4:-${JUMPBOX_USERNAME:-"adminuser"}}
ENV_TAG=${5:-${ENV_TAG:-"stac-${ENV_CODE}"}}
DEPLOYMENT_NAME=${6:-${DEPLOYMENT_NAME:-"${ENV_TAG}-deploy"}}
CONFIGURE_POD_IDENTITY=${7:-${CONFIGURE_POD_IDENTITY:-"false"}}
ENABLE_PUBLIC_ACCESS=${8:-${ENABLE_PUBLIC_ACCESS:-"false"}}
USER_OBJ_ID=${USER_OBJ_ID:-"$(az ad signed-in-user show --query id --output tsv 2> /dev/null || echo '')"}
LB_PRIVATE_IP=${LB_PRIVATE_IP:-"10.6.3.254"}

if [[ -z "$USER_OBJ_ID" ]]
  then
    echo "Set USER_OBJ_ID environment variable after retrieving the value from device with an approved MDM provider like Intune"
    echo "To get USER_OBJ_ID, run 'az ad signed-in-user show --query id --output tsv'"
fi

az feature register --namespace "Microsoft.ContainerService" --name "EnableWorkloadIdentityPreview"

# Captures the Azure cloud endpoints/suffixes
az cloud show -o json > $PRJ_ROOT/deploy/cloud_endpoints.json

DEPLOYMENT_SCRIPT="az deployment sub create -l $LOCATION -n $DEPLOYMENT_NAME \
    -f $PRJ_ROOT/deploy/bicep/main.bicep \
    -p \
    location=$LOCATION \
    environmentCode=$ENV_CODE \
    environment=$ENV_TAG \
    jumpboxAdminUsername=$JUMPBOX_USERNAME \
    jumpboxAdminPassword=$JUMPBOX_PASSWORD \
    loadBalancerPrivateIP=$LB_PRIVATE_IP \
    enablePublicAccess=$ENABLE_PUBLIC_ACCESS \
    owner_aad_object_id=$USER_OBJ_ID"
$DEPLOYMENT_SCRIPT