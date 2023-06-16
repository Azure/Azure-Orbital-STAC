#!/usr/bin/env bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

PRJ_ROOT="$(cd `dirname "${BASH_SOURCE}"`/../..; pwd)"
ENV_CODE=${1:-${ENV_CODE}}

[[ -z "$ENV_CODE" ]] && { echo "Environment Code value not supplied"; exit 1; }

set -ae
ENV_NAME=${ENV_NAME:-"stac-${ENV_CODE}"}
STAC_FASTAPI_VERSION=${STAC_FASTAPI_VERSION:-"2.4.8"}
STAC_BROWSER_VERSION=${STAC_BROWSER_VERSION:-"3.0.2"}
PROCESSING_RESOURCE_GROUP=${PROCESSING_RESOURCE_GROUP:-"${ENV_CODE}-processing-rg"}

ACR_NAME=$(az acr list -g ${PROCESSING_RESOURCE_GROUP} \
    --query "[?tags.environment && tags.environment == '$ENV_NAME'].name" -otsv)

echo "Building stac-cli Docker image in ACR"
az acr build -o none --no-logs --registry $ACR_NAME --image stac-cli ${PRJ_ROOT}

# build stac-fastapi-pgstac from https://github.com/stac-utils/stac-fastapi-pgstac/archive/refs/tags/${STAC_FASTAPI_VERSION}.tar.gz
STAC_FASTAPI_SRC_DIR=${STAC_FASTAPI_SRC_DIR:-"${PRJ_ROOT}/src/stac_fastapi_pgstac_k8s/src"}
STAC_FASTAPI_RELEASE_URI=${STAC_FASTAPI_RELEASE_URI:-"https://github.com/stac-utils/stac-fastapi-pgstac/archive/refs/tags/${STAC_FASTAPI_VERSION}.tar.gz"}
mkdir -p $STAC_FASTAPI_SRC_DIR
wget $STAC_FASTAPI_RELEASE_URI -P $STAC_FASTAPI_SRC_DIR
tar xf ${STAC_FASTAPI_SRC_DIR}/${STAC_FASTAPI_VERSION}.tar.gz -C ${STAC_FASTAPI_SRC_DIR}
echo "Building stac-fastapi-pgstac Docker image in ACR"
az acr build -o none --no-logs --registry $ACR_NAME --image stac-fastapi-pgstac \
  --file ${STAC_FASTAPI_SRC_DIR}/stac-fastapi-pgstac-${STAC_FASTAPI_VERSION}/Dockerfile \
  ${STAC_FASTAPI_SRC_DIR}/stac-fastapi-pgstac-${STAC_FASTAPI_VERSION}
rm -rf ${STAC_FASTAPI_SRC_DIR}

# build stac-browser from https://github.com/radiantearth/stac-browser/archive/refs/tags/v${STAC_BROWSER_VERSION}.tar.gz
FQDN=$(az network public-ip show -g $PROCESSING_RESOURCE_GROUP -n ${ENV_CODE}-stac-ingress-public-ip \
    --query dnsSettings.fqdn -o tsv)
STAC_BROWSER_SRC_DIR=${STAC_BROWSER_SRC_DIR:-"${PRJ_ROOT}/src/stac_browser_k8s/src"}
STAC_BROWSER_RELEASE_URI=${STAC_BROWSER_RELEASE_URI:-"https://github.com/radiantearth/stac-browser/archive/refs/tags/v${STAC_BROWSER_VERSION}.tar.gz"}
mkdir -p $STAC_BROWSER_SRC_DIR
wget $STAC_BROWSER_RELEASE_URI -P $STAC_BROWSER_SRC_DIR
tar xf ${STAC_BROWSER_SRC_DIR}/v${STAC_BROWSER_VERSION}.tar.gz -C ${STAC_BROWSER_SRC_DIR}
echo "Building stac-browser Docker image in ACR"
az acr build -o none --no-logs --registry $ACR_NAME --image stac-browser \
  --build-arg 'catalogURL='"'"'https://'$FQDN'/api/ --pathPrefix="/browser/"'"'"'' \
  ${STAC_BROWSER_SRC_DIR}/stac-browser-${STAC_BROWSER_VERSION}
rm -rf ${STAC_BROWSER_SRC_DIR}
