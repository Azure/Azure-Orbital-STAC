#!/usr/bin/env bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

PRJ_ROOT="$(cd `dirname "${BASH_SOURCE}"`/../..; pwd)"
ENV_CODE=${1:-${ENV_CODE}}
LOCATION=${2:-${LOCATION}}
LE_EMAIL_ADDRESS=${3:-${LE_EMAIL_ADDRESS}}
JUMPBOX_PASSWORD=${4:-${JUMPBOX_PASSWORD}}
JUMPBOX_USERNAME=${5:-${JUMPBOX_USERNAME:-"adminuser"}}

set -e

[[ -z "$ENV_CODE" ]] && { echo "Environment Code value not supplied"; exit 1; }
[[ -z "$LOCATION" ]] && { echo "Location value not supplied"; exit 1; }
[[ -z "$JUMPBOX_PASSWORD" ]] && { echo "Jumpbox Password not supplied"; exit 1; }
[[ -z "$LE_EMAIL_ADDRESS" ]] && { echo "Let's Encrypt e-mail address (LE_EMAIL_ADDRESS) not specified"; exit 1; }

echo "Performing bicep template deployment"
$PRJ_ROOT/deploy/scripts/install.sh "$ENV_CODE" "$LOCATION" "$JUMPBOX_PASSWORD" "$JUMPBOX_USERNAME"

echo "Building containers and Deploying to Infra"
$PRJ_ROOT/deploy/scripts/build.sh "$ENV_CODE"

echo "Performing configuration and Deploying Apps"
LE_EMAIL_ADDRESS="$LE_EMAIL_ADDRESS" \
$PRJ_ROOT/deploy/scripts/configure.sh "$ENV_CODE"

echo "Securing Keyvault access"
$PRJ_ROOT/deploy/scripts/secure-keyvault.sh "$ENV_CODE"
