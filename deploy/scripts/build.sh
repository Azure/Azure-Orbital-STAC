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
STAC_FASTAPI_VERSION=${STAC_FASTAPI_VERSION:-"2.4.0"}
PROCESSING_RESOURCE_GROUP=${PROCESSING_RESOURCE_GROUP:-"${ENV_CODE}-processing-rg"}

ACR_NAME=$(az acr list -g ${PROCESSING_RESOURCE_GROUP} \
    --query "[?tags.environment && tags.environment == '$ENV_NAME'].name" -otsv)

az acr build --registry $ACR_NAME --image stac-cli ${PRJ_ROOT}/src/azure-stac-cli/

# build stac-fastapi from https://github.com/stac-utils/stac-fastapi/archive/refs/tags/${STAC_FASTAPI_VERSION}.tar.gz
STAC_FASTAPI_SRC_DIR=${STAC_FASTAPI_SRC_DIR:-"${PRJ_ROOT}/src/stac_fastapi_k8s/src"}
STAC_FASTAPI_RELEASE_URI=${STAC_FASTAPI_RELEASE_URI:-"https://github.com/stac-utils/stac-fastapi/archive/refs/tags/${STAC_FASTAPI_VERSION}.tar.gz"}
mkdir -p $STAC_FASTAPI_SRC_DIR
# wget $STAC_FASTAPI_RELEASE_URI -P $STAC_FASTAPI_SRC_DIR
# tar xvf ${STAC_FASTAPI_SRC_DIR}/${STAC_FASTAPI_VERSION}.tar.gz -C ${STAC_FASTAPI_SRC_DIR}
# az acr build --registry $ACR_NAME --image stac-fastapi ${STAC_FASTAPI_SRC_DIR}/stac-fastapi-${STAC_FASTAPI_VERSION}

# Released versions of stac-fastapi are broken because of an unreleased fix https://github.com/stac-utils/stac-fastapi/pull/466
# Using github master branch for the build as of now
# TODO: Uncomment the code above and comment/remove this code which pulls stac-fastapi from master branch
git clone https://github.com/stac-utils/stac-fastapi $STAC_FASTAPI_SRC_DIR/stac-fastapi
CURRENT_WORKING_DIRECTORY="$(pwd)"
cd $STAC_FASTAPI_SRC_DIR/stac-fastapi
git reset --hard da012a635b1c0185d40595db11c76ac9f110d796
cd $CURRENT_WORKING_DIRECTORY

# This is temporary fix until we find a better solution for this fix
# issue - pypgstac cmdline for ingesting the STAC collection and item are 
# at 0.6.11 and the database (postgresql) is getting bootstrapped to 0.6.13.
# These two versions need to match. This fix holds these versions to 0.6.11.
SED_INLINE="-i"
if [[ "$(uname)" == "Darwin"* ]]; then
    SED_INLINE="-i ''"
fi
sed "${SED_INLINE[@]}" 's/0.6.12/0.6.11/' $STAC_FASTAPI_SRC_DIR/stac-fastapi/docker-compose.yml
sed "${SED_INLINE[@]}" 's/0.6.\*/0.6.11/' $STAC_FASTAPI_SRC_DIR/stac-fastapi/stac_fastapi/pgstac/setup.py

az acr build --registry $ACR_NAME --image stac-fastapi ${STAC_FASTAPI_SRC_DIR}/stac-fastapi
rm -rf ${STAC_FASTAPI_SRC_DIR}