#!/usr/bin/env bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

PRJ_ROOT="$(cd `dirname "${BASH_SOURCE}"`/../..; pwd)"
ENV_CODE=${1:-${ENV_CODE}}
LOCATION=${2:-${LOCATION}}
JUMPBOX_PASSWORD=${3:-${JUMPBOX_PASSWORD}}
JUMPBOX_USERNAME=${4:-${JUMPBOX_USERNAME:-"adminuser"}}

set -e

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

echo "Performing bicep template deployment"
$PRJ_ROOT/deploy/scripts/install.sh "$ENV_CODE" "$LOCATION" "$JUMPBOX_PASSWORD" "$JUMPBOX_USERNAME"

echo "Building containers and Deploying to Infra"
$PRJ_ROOT/deploy/scripts/build.sh "$ENV_CODE"

echo "Performing configuration and Deploying Apps"
$PRJ_ROOT/deploy/scripts/configure.sh "$ENV_CODE"

echo "Securing Keyvault access"
$PRJ_ROOT/deploy/scripts/secure-keyvault.sh "$ENV_CODE"
