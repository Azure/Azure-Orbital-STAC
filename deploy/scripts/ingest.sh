#!/usr/bin/env bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.


SRC_STORAGE_ACCOUNT_NAME=$1
SRC_STORAGE_ACCOUNT_RG=$2
SRC_CONTAINER_NAME=$3

DST_STORAGE_ACCOUNT_NAME=$4
DST_STORAGE_ACCOUNT_RG=$5
DST_CONTAINER_NAME=$6

if [[ -z "$1" ]]
  then
    echo "value for SRC_STORAGE_ACCOUNT_NAME not supplied"
    exit 1
fi

if [[ -z "$2" ]]
  then
    echo "value for SRC_STORAGE_ACCOUNT_RG not supplied"
    exit 1
fi

if [[ -z "$3" ]]
  then
    echo "value for SRC_CONTAINER_NAME not supplied"
    exit 1
fi

if [[ -z "$4" ]]
  then
    echo "value for DST_STORAGE_ACCOUNT_NAME not supplied"
    exit 1
fi

if [[ -z "$5" ]]
  then
    echo "value for DST_STORAGE_ACCOUNT_RG not supplied"
    exit 1
fi

if [[ -z "$6" ]]
  then
    echo "value for DST_CONTAINER_NAME not supplied"
    exit 1
fi

set -a



SRC_STORAGE_ACCOUNT_KEY=$(az storage account keys list \
    --account-name ${SRC_STORAGE_ACCOUNT_NAME} \
    --resource-group ${SRC_STORAGE_ACCOUNT_RG} \
    --query "[0].value" -o tsv)

SRC_STORAGE_ACCOUNT_SAS=$(az storage account generate-sas \
    --account-name ${SRC_STORAGE_ACCOUNT_NAME} \
    --services bfqt \
    --resource-types cso \
    --permissions rwdlacupiytfx \
    --expiry  $(date -d '+2 day' '+%Y-%m-%d'))

DST_STORAGE_ACCOUNT_KEY=$(az storage account keys list \
    --account-name ${DST_STORAGE_ACCOUNT_NAME} \
    --resource-group ${DST_STORAGE_ACCOUNT_RG} \
    --query "[0].value" -o tsv)


DST_STORAGE_ACCOUNT_SAS=$(az storage account generate-sas \
    --account-name ${DST_STORAGE_ACCOUNT_NAME} \
    --services bfqt \
    --resource-types cso \
    --permissions rwdlacupiytfx \
    --expiry  $(date -d '+2 day' '+%Y-%m-%d'))

regions=(al ar az ca)

for region in "${regions[@]}"
do
  echo "Iterating through the first level of folders ..."

  YEAR_FOLDERS=$(az storage blob directory list --container ${SRC_CONTAINER_NAME} \
      --directory-path "v002/${region}" \
      --account-name ${SRC_STORAGE_ACCOUNT_NAME} \
      --delimiter '/' | jq -r '.[].name')

  while IFS= read -r line; do
    echo "...Procesing --> $line..."
    if [[ "$line" == */ ]]
    then
      echo "Iterating through the second level of folders ..."

      FIRST_LEVEL_FOLDER=$(az storage blob directory list --container ${SRC_CONTAINER_NAME} \
          --directory-path "${line::-1}" \
          --account-name ${SRC_STORAGE_ACCOUNT_NAME} \
          --delimiter '/' | jq -r '.[].name')
      echo "$FIRST_LEVEL_FOLDER"
      while IFS= read -r frst_lvl_line; do
        echo ".....Procesing --> $frst_lvl_line"
        if [[ "$frst_lvl_line" == *cm_* || "$frst_lvl_line" == *_fgdc_* ]]
        then
          echo "Iterating through the third level of folders ..."

          SECOND_LEVEL_FOLDER=$(az storage blob directory list --container ${SRC_CONTAINER_NAME} \
              --directory-path "${frst_lvl_line::-1}" \
              --account-name ${SRC_STORAGE_ACCOUNT_NAME} \
              --delimiter '/' | jq -r '.[].name')
          while IFS= read -r scnd_lvl_line; do
            echo ".......Procesing --> $scnd_lvl_line"

            if [[ "$scnd_lvl_line" == */ ]]
            then
              scnd_lvl_line=${scnd_lvl_line::-1}
              echo "***Copying data from 'https://${SRC_STORAGE_ACCOUNT_NAME}.blob.core.windows.net/${SRC_CONTAINER_NAME}/${scnd_lvl_line}?${SRC_STORAGE_ACCOUNT_SAS:1:-1}'" \
                "to 'https://${DST_STORAGE_ACCOUNT_NAME}.blob.core.windows.net/${DST_CONTAINER_NAME}/${scnd_lvl_line}?${DST_STORAGE_ACCOUNT_SAS:1:-1}'***"
              azcopy copy "https://${SRC_STORAGE_ACCOUNT_NAME}.blob.core.windows.net/${SRC_CONTAINER_NAME}/${scnd_lvl_line}?${SRC_STORAGE_ACCOUNT_SAS:1:-1}" \
                "https://${DST_STORAGE_ACCOUNT_NAME}.blob.core.windows.net/${DST_CONTAINER_NAME}/${scnd_lvl_line%/*}?${DST_STORAGE_ACCOUNT_SAS:1:-1}" --recursive
            fi
          done <<< "$SECOND_LEVEL_FOLDER"
        fi
      done <<< "$FIRST_LEVEL_FOLDER"
    else
      echo "Oops! control is in else section"
    fi
  done <<< "$YEAR_FOLDERS"
done

set +a
