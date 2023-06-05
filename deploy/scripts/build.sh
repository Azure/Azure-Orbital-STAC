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

set -ae
ENV_NAME=${ENV_NAME:-"stac-${ENV_CODE}"}
STAC_FASTAPI_VERSION=${STAC_FASTAPI_VERSION:-"2.4.4"}
PROCESSING_RESOURCE_GROUP=${PROCESSING_RESOURCE_GROUP:-"${ENV_CODE}-processing-rg"}

ACR_NAME=$(az acr list -g ${PROCESSING_RESOURCE_GROUP} \
    --query "[?tags.environment && tags.environment == '$ENV_NAME'].name" -otsv)

az acr build --registry $ACR_NAME --image stac-cli ${PRJ_ROOT}

# build stac-fastapi from https://github.com/stac-utils/stac-fastapi/archive/refs/tags/${STAC_FASTAPI_VERSION}.tar.gz
STAC_FASTAPI_SRC_DIR=${STAC_FASTAPI_SRC_DIR:-"${PRJ_ROOT}/src/stac_fastapi_k8s/src"}
STAC_FASTAPI_RELEASE_URI=${STAC_FASTAPI_RELEASE_URI:-"https://github.com/stac-utils/stac-fastapi/archive/refs/tags/${STAC_FASTAPI_VERSION}.tar.gz"}
mkdir -p $STAC_FASTAPI_SRC_DIR
wget $STAC_FASTAPI_RELEASE_URI -P $STAC_FASTAPI_SRC_DIR
tar xvf ${STAC_FASTAPI_SRC_DIR}/${STAC_FASTAPI_VERSION}.tar.gz -C ${STAC_FASTAPI_SRC_DIR}
az acr build --registry $ACR_NAME --image stac-fastapi --file ${STAC_FASTAPI_SRC_DIR}/stac-fastapi-${STAC_FASTAPI_VERSION}/docker/Dockerfile ${STAC_FASTAPI_SRC_DIR}/stac-fastapi-${STAC_FASTAPI_VERSION}
rm -rf ${STAC_FASTAPI_SRC_DIR}
