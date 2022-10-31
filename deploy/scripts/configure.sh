#!/usr/bin/env bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

PRJ_ROOT="$(cd `dirname "${BASH_SOURCE}"`/../..; pwd)"
ENV_CODE=${1:-${ENV_CODE}}

if [[ -z "$1" ]]
  then
    echo "Environment Code value not supplied"
    exit 1
fi

set -a
ENV_NAME=${ENV_NAME:-"stac-${ENV_CODE}"}
MONITORING_RESOURCE_GROUP=${MONITORING_RESOURCE_GROUP:-"${ENV_CODE}-monitoring-rg"}
VNET_RESOURCE_GROUP=${VNET_RESOURCE_GROUP:-"${ENV_CODE}-vnet-rg"}
DATA_RESOURCE_GROUP=${DATA_RESOURCE_GROUP:-"${ENV_CODE}-data-rg"}
PROCESSING_RESOURCE_GROUP=${PROCESSING_RESOURCE_GROUP:-"${ENV_CODE}-processing-rg"}

SUBSCRIPTION=$(az account show --query id -o tsv)
AZURE_APP_INSIGHTS=$(az resource list -g $MONITORING_RESOURCE_GROUP --resource-type "Microsoft.Insights/components" \
    --query "[?tags.environment && tags.environment == '$ENV_NAME'].name" -o tsv)

AZURE_LOG_CONNECTION_STRING=$(az resource show \
    -g $MONITORING_RESOURCE_GROUP \
    --resource-type Microsoft.Insights/components \
    -n ${AZURE_APP_INSIGHTS} \
    --query "properties.ConnectionString" -o tsv)

DATA_STORAGE_ACCOUNT_NAME=$(az storage account list \
    --query "[?tags.store && tags.store == 'data'].name" -o tsv -g ${DATA_RESOURCE_GROUP})
DATA_STORAGE_ACCOUNT_KEY=$(az storage account keys list \
    --account-name ${DATA_STORAGE_ACCOUNT_NAME} --resource-group ${DATA_RESOURCE_GROUP} \
    --query "[0].value" -o tsv)
STORAGE_ACCOUNT_ENDPOINT_SUFFIX=$(az cloud show --query suffixes.storageEndpoint --output tsv)

DATA_STORAGE_ACCOUNT_CONNECTION_STRING="DefaultEndpointsProtocol=https;EndpointSuffix=$STORAGE_ACCOUNT_ENDPOINT_SUFFIX;AccountName=$DATA_STORAGE_ACCOUNT_NAME;AccountKey=$DATA_STORAGE_ACCOUNT_KEY"

AKS_RESOURCE_GROUP=${AKS_RESOURCE_GROUP:-${PROCESSING_RESOURCE_GROUP}}
AKS_CLUSTER_NAME=$(az aks list -g ${PROCESSING_RESOURCE_GROUP} \
    --query "[?tags.type && tags.type == 'k8s'].name" -otsv)
ACR_DNS=$(az acr list -g ${PROCESSING_RESOURCE_GROUP} \
    --query "[?tags.environment && tags.environment == '$ENV_NAME'].loginServer" -otsv)
SERVICE_BUS_NAMESPACE=$(az servicebus namespace list \
    -g ${DATA_RESOURCE_GROUP} --query "[?tags.environment && tags.environment == '$ENV_NAME'].name" -otsv)

STAC_METADATA_TYPE_NAME=${STAC_METADATA_TYPE_NAME:-"fgdc"}
COLLECTION_ID=${COLLECTION_ID:-"naip"}
JPG_EXTENSION=${JPG_EXTENSION:-"200.jpg"}
XML_EXTENSION=${XML_EXTENSION:-"aux.xml"}
REPLICAS=${REPLICAS:-"3"}
POD_CPU=${POD_CPU:-"0.5"}
POD_MEMORY=${POD_MEMORY:-"2Gi"}

GENERATE_STAC_JSON_IMAGE_NAME=${GENERATE_STAC_JSON_IMAGE_NAME:-"generate-stac-json"}
DATA_STORAGE_PGSTAC_CONTAINER_NAME=${DATA_STORAGE_PGSTAC_CONTAINER_NAME:-"pgstac"}
ENV_LABLE=${ENV_LABLE:-"stacpool"} # aks agent pool name to deploy kubectl deployment yaml files

SERVICE_BUS_AUTH_POLICY_NAME=${SERVICE_BUS_AUTH_POLICY_NAME:-"RootManageSharedAccessKey"}
SERVICE_BUS_CONNECTION_STRING=$(az servicebus namespace authorization-rule keys list \
    --resource-group ${DATA_RESOURCE_GROUP} \
    --namespace-name ${SERVICE_BUS_NAMESPACE} \
    --name ${SERVICE_BUS_AUTH_POLICY_NAME} \
    --query "primaryConnectionString" -otsv)

STAC_EVENT_CONSUMER_IMAGE_NAME=${STAC_EVENT_CONSUMER_IMAGE_NAME:-"stac-event-consumer"}
PGSTAC_SERVICE_BUS_TOPIC_NAME=${PGSTAC_SERVICE_BUS_TOPIC_NAME:-"pgstactopic"}
PGSTAC_SERVICE_BUS_TOPIC_AUTH_POLICY_NAME=${PGSTAC_SERVICE_BUS_TOPIC_AUTH_POLICY_NAME:-"pgstacpolicy"}
PGSTAC_SERVICE_BUS_SUBSCRIPTION_NAME=${PGSTAC_SERVICE_BUS_SUBSCRIPTION_NAME:-"pgstacsubscription"}
PGSTAC_SERVICE_BUS_CONNECTION_STRING=$(az servicebus topic authorization-rule keys list \
    --resource-group ${DATA_RESOURCE_GROUP} \
    --namespace-name ${SERVICE_BUS_NAMESPACE} \
    --topic ${PGSTAC_SERVICE_BUS_TOPIC_NAME} \
    --name ${PGSTAC_SERVICE_BUS_TOPIC_AUTH_POLICY_NAME} \
    --query "primaryConnectionString" -otsv)

GENERATED_STAC_STORAGE_CONTAINER_NAME=${GENERATED_STAC_STORAGE_CONTAINER_NAME:-"generatedstacjson"}

KEY_VAULT_NAME=$(az keyvault list --query "[?tags.environment && tags.environment == '$ENV_NAME'].name" -o tsv -g $DATA_RESOURCE_GROUP)
PGHOST=$(az postgres flexible-server list --resource-group $DATA_RESOURCE_GROUP --query '[].fullyQualifiedDomainName' -o tsv)
PGHOSTONLY=$(az postgres flexible-server list --resource-group $DATA_RESOURCE_GROUP --query '[].name' -o tsv)
PGUSER=$(az postgres flexible-server list --resource-group $DATA_RESOURCE_GROUP --query '[].administratorLogin' -o tsv)
PGPASSWORD_SECRET_NAME=${PGPASSWORD_SECRET_NAME:-"PGAdminLoginPass"}
PGPASSWORD=$(az keyvault secret show --vault-name $KEY_VAULT_NAME --name $PGPASSWORD_SECRET_NAME --query value -o tsv)
PGDATABASE=${PGDATABASE:-"postgres"}
PGPORT=${PGPORT:-"5432"}
LB_PRIVATE_IP=${LB_PRIVATE_IP:-"10.6.3.254"}

STACIFY_STORAGE_CONTAINER_NAME=${STACIFY_STORAGE_CONTAINER_NAME:-"stacify"}
STACIFY_SERVICE_BUS_TOPIC_NAME=${STACIFY_SERVICE_BUS_TOPIC_NAME:-"stacifytopic"}
STACIFY_SERVICE_BUS_TOPIC_AUTH_POLICY_NAME=${STACIFY_SERVICE_BUS_TOPIC_AUTH_POLICY_NAME:-"stacifypolicy"}
STACIFY_SERVICE_BUS_SUBSCRIPTION_NAME=${STACIFY_SERVICE_BUS_SUBSCRIPTION_NAME:-"stacifysubscription"}
STACIFY_SERVICE_BUS_CONNECTION_STRING=$(az servicebus topic authorization-rule keys list \
    --resource-group ${DATA_RESOURCE_GROUP} \
    --namespace-name ${SERVICE_BUS_NAMESPACE} \
    --topic ${STACIFY_SERVICE_BUS_TOPIC_NAME} \
    --name ${STACIFY_SERVICE_BUS_TOPIC_AUTH_POLICY_NAME} \
    --query "primaryConnectionString" -otsv)

STAC_COLLECTION_IMAGE_NAME=${STAC_COLLECTION_IMAGE_NAME:-"stac-collection"}
STACCOLLECTION_STORAGE_CONTAINER_NAME=${STACCOLLECTION_STORAGE_CONTAINER_NAME:-"staccollection"}
STACCOLLECTION_SERVICE_BUS_TOPIC_NAME=${STACCOLLECTION_SERVICE_BUS_TOPIC_NAME:-"staccollectiontopic"}
STACCOLLECTION_SERVICE_BUS_AUTH_POLICY_NAME=${STACCOLLECTION_SERVICE_BUS_AUTH_POLICY_NAME:-"staccollectionpolicy"}
STACCOLLECTION_SERVICE_BUS_SUBSCRIPTION_NAME=${STACCOLLEcTION_SERVICE_BUS_SUBSCRIPTION_NAME:-"staccollectionsubscription"}
STACCOLLECTION_SERVICE_BUS_CONNECTION_STRING=$(az servicebus topic authorization-rule keys list \
    --resource-group ${DATA_RESOURCE_GROUP} \
    --namespace-name ${SERVICE_BUS_NAMESPACE} \
    --topic ${STACCOLLECTION_SERVICE_BUS_TOPIC_NAME} \
    --name ${STACCOLLECTION_SERVICE_BUS_AUTH_POLICY_NAME} \
    --query "primaryConnectionString" -otsv)

AKS_NAMESPACE=${AKS_NAMESPACE:-"pgstac"}
ENV_LABEL=${ENV_LABEL:-"stacpool"} # aks agent pool name to deploy kubectl deployment yaml files
set +a
export -p

echo 'enabling POSTGIS,BTREE_GIST in postgres'
az postgres flexible-server \
    parameter set \
    --resource-group $DATA_RESOURCE_GROUP --server-name $PGHOSTONLY \
    --subscription $SUBSCRIPTION --name azure.extensions --value POSTGIS,BTREE_GIST

az aks get-credentials --resource-group ${AKS_RESOURCE_GROUP} --name ${AKS_CLUSTER_NAME} --context ${AKS_CLUSTER_NAME} --overwrite-existing
kubectl config set-context ${AKS_CLUSTER_NAME}

NS=$(kubectl get namespace $AKS_NAMESPACE --ignore-not-found);
if [[ "$NS" ]]; then
    echo "Skipping creation of ${AKS_NAMESPACE} namespace in k8s cluster as it already exists"
else
    echo "Creating ${AKS_NAMESPACE} namespace in k8s cluster"
    kubectl create namespace ${AKS_NAMESPACE}
fi; 

echo "deploying stacfastapi"
#helm install stac-scaler ${PRJ_ROOT} -n $AKS_NAMESPACE apply -f -

echo "Deploying chart to Kubernetes Cluster"
helm install stac-scaler ${PRJ_ROOT}/deploy/helm/stac-scaler \
    --namespace pgstac \
    --set serviceBusConnectionString=${SERVICE_BUS_CONNECTION_STRING} \
    --set processors.stac-collection.namespace=${SERVICE_BUS_NAMESPACE} \
    --set processors.stac-collection.image.repository=${ACR_DNS} \
    --set processors.stac-collection.env.STACCOLLECTION_SERVICE_BUS_CONNECTION_STRING=${STACCOLLECTION_SERVICE_BUS_CONNECTION_STRING} \
    --set processors.stac-collection.env.STACCOLLECTION_SERVICE_BUS_TOPIC_NAME=${STACCOLLECTION_SERVICE_BUS_TOPIC_NAME} \
    --set processors.stac-collection.env.STACCOLLECTION_SERVICE_BUS_SUBSCRIPTION_NAME=${STACCOLLECTION_SERVICE_BUS_SUBSCRIPTION_NAME} \
    --set processors.stac-collection.env.DATA_STORAGE_ACCOUNT_CONNECTION_STRING=${DATA_STORAGE_ACCOUNT_CONNECTION_STRING} \
    --set processors.stac-collection.env.DATA_STORAGE_ACCOUNT_NAME=${DATA_STORAGE_ACCOUNT_NAME} \
    --set processors.stac-collection.env.DATA_STORAGE_ACCOUNT_KEY=${DATA_STORAGE_ACCOUNT_KEY} \
    --set processors.stac-collection.env.STACCOLLECTION_STORAGE_CONTAINER_NAME=${STACCOLLECTION_STORAGE_CONTAINER_NAME} \
    --set processors.stac-collection.env.AZURE_LOG_CONNECTION_STRING=${AZURE_LOG_CONNECTION_STRING} \
    --set processors.stac-collection.env.PGHOST=${PGHOST} \
    --set processors.stac-collection.env.PGPORT=5432 \
    --set processors.stac-collection.env.PGUSER=${PGUSER} \
    --set processors.stac-collection.env.PGDATABASE=${PGDATABASE} \
    --set processors.stac-collection.env.PGPASSWORD=${PGPASSWORD} \
    --set processors.stac-event-consumer.namespace=${SERVICE_BUS_NAMESPACE} \
    --set processors.stac-event-consumer.image.repository=${ACR_DNS} \
    --set processors.stac-event-consumer.env.PGSTAC_SERVICE_BUS_CONNECTION_STRING=${PGSTAC_SERVICE_BUS_CONNECTION_STRING} \
    --set processors.stac-event-consumer.env.PGSTAC_SERVICE_BUS_TOPIC_NAME=${PGSTAC_SERVICE_BUS_TOPIC_NAME} \
    --set processors.stac-event-consumer.env.PGSTAC_SERVICE_BUS_SUBSCRIPTION_NAME=${PGSTAC_SERVICE_BUS_SUBSCRIPTION_NAME} \
    --set processors.stac-event-consumer.env.DATA_STORAGE_ACCOUNT_CONNECTION_STRING=${DATA_STORAGE_ACCOUNT_CONNECTION_STRING} \
    --set processors.stac-event-consumer.env.GENERATED_STAC_STORAGE_CONTAINER_NAME=${GENERATED_STAC_STORAGE_CONTAINER_NAME} \
    --set processors.stac-event-consumer.env.AZURE_LOG_CONNECTION_STRING=${AZURE_LOG_CONNECTION_STRING} \
    --set processors.stac-event-consumer.env.DATA_STORAGE_PGSTAC_CONTAINER_NAME=${DATA_STORAGE_PGSTAC_CONTAINER_NAME} \
    --set processors.stac-event-consumer.env.PGHOST=${PGHOST} \
    --set processors.stac-event-consumer.env.PGPORT=5432 \
    --set processors.stac-event-consumer.env.PGUSER=${PGUSER} \
    --set processors.stac-event-consumer.env.PGDATABASE=${PGDATABASE} \
    --set processors.stac-event-consumer.env.PGPASSWORD=${PGPASSWORD} \
    --set processors.generate-stac-json.namespace=${SERVICE_BUS_NAMESPACE} \
    --set processors.generate-stac-json.image.repository=${ACR_DNS} \
    --set processors.generate-stac-json.env.DATA_STORAGE_ACCOUNT_CONNECTION_STRING=${DATA_STORAGE_ACCOUNT_CONNECTION_STRING} \
    --set processors.generate-stac-json.env.DATA_STORAGE_ACCOUNT_NAME=${DATA_STORAGE_ACCOUNT_NAME} \
    --set processors.generate-stac-json.env.DATA_STORAGE_ACCOUNT_KEY=${DATA_STORAGE_ACCOUNT_KEY} \
    --set processors.generate-stac-json.env.STACIFY_STORAGE_CONTAINER_NAME=${STACIFY_STORAGE_CONTAINER_NAME} \
    --set processors.generate-stac-json.env.STACIFY_SERVICE_BUS_CONNECTION_STRING=${STACIFY_SERVICE_BUS_CONNECTION_STRING} \
    --set processors.generate-stac-json.env.STACIFY_SERVICE_BUS_TOPIC_NAME=${STACIFY_SERVICE_BUS_TOPIC_NAME} \
    --set processors.generate-stac-json.env.STACIFY_SERVICE_BUS_SUBSCRIPTION_NAME=${STACIFY_SERVICE_BUS_SUBSCRIPTION_NAME} \
    --set processors.generate-stac-json.env.GENERATED_STAC_STORAGE_CONTAINER_NAME=${GENERATED_STAC_STORAGE_CONTAINER_NAME} \
    --set processors.generate-stac-json.env.AZURE_LOG_CONNECTION_STRING=${AZURE_LOG_CONNECTION_STRING} \
    --set processors.generate-stac-json.env.DATA_STORAGE_PGSTAC_CONTAINER_NAME=${DATA_STORAGE_PGSTAC_CONTAINER_NAME} \
    --set processors.generate-stac-json.env.STAC_METADATA_TYPE_NAME=${STAC_METADATA_TYPE_NAME} \
    --set processors.generate-stac-json.env.JPG_EXTENSION=${JPG_EXTENSION} \
    --set processors.generate-stac-json.env.XML_EXTENSION=${XML_EXTENSION} \
    --set processors.generate-stac-json.env.COLLECTION_ID=${COLLECTION_ID} \
    --set stacfastapi.image.repository=${ACR_DNS} \
    --set stacfastapi.env.POSTGRES_HOST_READER=${PGHOST} \
    --set stacfastapi.env.POSTGRES_HOST_WRITER=${PGHOST} \
    --set stacfastapi.env.POSTGRES_PASS=${PGPASSWORD} \
    --set stacfastapi.env.POSTGRES_USER=${PGUSER} \
    --set stacfastapi.env.PGUSER=${PGUSER} \
    --set stacfastapi.env.PGPASSWORD=${PGPASSWORD} \
    --set stacfastapi.env.PGHOST=${PGHOST}    
