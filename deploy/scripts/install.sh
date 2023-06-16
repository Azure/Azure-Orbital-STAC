#!/usr/bin/env bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

set -e
PRJ_ROOT="$(cd `dirname "${BASH_SOURCE}"`/../..; pwd)"

# Setup required parameters
ENV_CODE=${1:-${ENV_CODE}}
LOCATION=${2:-${LOCATION}}
JUMPBOX_PASSWORD=${3:-${JUMPBOX_PASSWORD}}

if [[ -z "$ENV_CODE" ]]
  then
    echo "Environment Code value not supplied"
    exit 1
fi

if [[ -z "$LOCATION" ]]
  then
    echo "Location value not supplied"
    exit 1
fi

if [[ -z "$JUMPBOX_PASSWORD" ]]
  then
    echo "Jumpbox Password not supplied"
    exit 1
fi

# Setup parameters
JUMPBOX_USERNAME=${4:-${JUMPBOX_USERNAME:-"adminuser"}}
ENV_TAG=${5:-${ENV_TAG:-"stac-${ENV_CODE}"}}
DEPLOYMENT_NAME=${6:-${DEPLOYMENT_NAME:-"${ENV_TAG}-deploy"}}
CONFIGURE_POD_IDENTITY=${7:-${CONFIGURE_POD_IDENTITY:-"false"}}
ENABLE_PUBLIC_ACCESS=${8:-${ENABLE_PUBLIC_ACCESS:-"false"}}
USER_OBJ_ID=${USER_OBJ_ID:-"$(az ad signed-in-user show --query id --output tsv 2> /dev/null || echo '')"}
POSTGRES_PRIVATE_ENDPOINT_DISABLED=${POSTGRES_PRIVATE_ENDPOINT_DISABLED:-false}
if [[ -n "$DNS_PREFIX" ]]; then
  DNS_ARG="ingressPublicIPDnsPrefix=$DNS_PREFIX"
fi

if [[ -z "$USER_OBJ_ID" ]]; then
  # If there was no "id" field, then try "objectId"
  USER_OBJ_ID="$(az ad signed-in-user show --query objectId --output tsv 2> /dev/null || echo '')"
fi
if [[ -z "$USER_OBJ_ID" ]]; then
    echo "Set USER_OBJ_ID environment variable after retrieving the value from device with an approved MDM provider like Intune"
    echo "To get USER_OBJ_ID, run 'az ad signed-in-user show --query id --output tsv'"
    exit 1
fi

# Register the workload identity feature, and wait for it to be registered.
if [[ $(az feature show --namespace "Microsoft.ContainerService" --name "EnableWorkloadIdentityPreview" --query properties.state -otsv) != "Registered" ]]; then
  echo "Registering workload identity preview with AKS."
  az feature register --namespace "Microsoft.ContainerService" --name "EnableWorkloadIdentityPreview"
  workload_identity_registered=true
fi
while [[ $(az feature show --namespace "Microsoft.ContainerService" --name "EnableWorkloadIdentityPreview" --query properties.state -otsv) != "Registered" ]]; do
  echo "Waiting for the workload identity preview feature to be registered."
  sleep 10
done
# If we actually registered the feature, then we need to re-register the provider to get the change to propagate
if [[ $workload_identity_registered ]]; then
  az provider register --namespace "Microsoft.ContainerService"
fi

# Captures the Azure cloud endpoints/suffixes
az cloud show -o json > $PRJ_ROOT/deploy/cloud_endpoints.json

# Minimum required version of Kubernetes is 1.22.0. We assume all regions have atleast 1.22.0 or later version
AKS_VERSION=$(az aks get-versions -l $LOCATION --query 'orchestrators[?!isPreview].orchestratorVersion' -otsv | sort -rV | head -n1)

DEPLOYMENT_SCRIPT="az deployment sub create -o none -l $LOCATION -n $DEPLOYMENT_NAME \
    -f $PRJ_ROOT/deploy/bicep/main.bicep \
    -p \
    location=$LOCATION \
    environmentCode=$ENV_CODE \
    environment=$ENV_TAG \
    kubernetesVersion=$AKS_VERSION \
    jumpboxAdminUsername=$JUMPBOX_USERNAME \
    jumpboxAdminPassword=$JUMPBOX_PASSWORD \
    enablePublicAccess=$ENABLE_PUBLIC_ACCESS \
    privateEndpointDisabled=$POSTGRES_PRIVATE_ENDPOINT_DISABLED \
    owner_aad_object_id=$USER_OBJ_ID $DNS_ARG"

$DEPLOYMENT_SCRIPT

for script in $(az deployment-scripts list -g "${ENV_CODE}-vnet-rg" --query "[].name" -o tsv); do
  az deployment-scripts delete -g "${ENV_CODE}-vnet-rg" --yes --name $script
done