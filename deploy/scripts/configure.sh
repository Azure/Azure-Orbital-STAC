#!/usr/bin/env bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

PRJ_ROOT="$(cd `dirname "${BASH_SOURCE}"`/../..; pwd)"
ENV_CODE=${1:-${ENV_CODE}}
LE_EMAIL_ADDRESS=${2:-${LE_EMAIL_ADDRESS}}

[[ -z "$ENV_CODE" ]] && { echo "Environment Code value not supplied"; exit 1; }
[[ -z "$LE_EMAIL_ADDRESS" ]] && { echo "Let's Encrypt e-mail address (LE_EMAIL_ADDRESS) not specified"; exit 1; }

set -a
set -e
ENV_NAME=${ENV_NAME:-"stac-${ENV_CODE}"}
MONITORING_RESOURCE_GROUP=${MONITORING_RESOURCE_GROUP:-"${ENV_CODE}-monitoring-rg"}
VNET_RESOURCE_GROUP=${VNET_RESOURCE_GROUP:-"${ENV_CODE}-vnet-rg"}
DATA_RESOURCE_GROUP=${DATA_RESOURCE_GROUP:-"${ENV_CODE}-data-rg"}
PROCESSING_RESOURCE_GROUP=${PROCESSING_RESOURCE_GROUP:-"${ENV_CODE}-processing-rg"}
UAMI=${UAMI:-"${ENV_CODE}-stacaks-mi"}

AKS_NAMESPACE=${AKS_NAMESPACE:-"pgstac"}
AKS_INGRESS_NAMESPACE=${AKS_INGRESS_NAMESPACE:-"ingress"}
ENV_LABEL=${ENV_LABEL:-"stacpool"} # aks agent pool name to deploy kubectl deployment yaml files
AKS_SERVICE_ACCOUNT_NAME=${AKS_SERVICE_ACCOUNT_NAME:-'stac-svc-acct'}
FEDERATED_IDENTITY_NAME="stacaksfederatedidentity"

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

DATA_STORAGE_ACCOUNT_CONNECTION_STRING=$(az storage account show-connection-string \
    --resource-group $DATA_RESOURCE_GROUP \
    --name $DATA_STORAGE_ACCOUNT_NAME \
    | jq -r ".connectionString")

DATA_STORAGE_ACCOUNT_BLOB_ENDPOINT=$(az storage account show -n $DATA_STORAGE_ACCOUNT_NAME \
    --query primaryEndpoints.blob -otsv)
DATA_STORAGE_ACCOUNT_BLOB_DOMAIN=${DATA_STORAGE_ACCOUNT_BLOB_ENDPOINT#https://}
DATA_STORAGE_ACCOUNT_BLOB_DOMAIN=${DATA_STORAGE_ACCOUNT_BLOB_DOMAIN%%/*}

AKS_RESOURCE_GROUP=${AKS_RESOURCE_GROUP:-${PROCESSING_RESOURCE_GROUP}}
AKS_CLUSTER_NAME=$(az aks list -g ${AKS_RESOURCE_GROUP} \
    --query "[?tags.type && tags.type == 'k8s'].name" -otsv)
ACR_DNS=$(az acr list -g ${PROCESSING_RESOURCE_GROUP} \
    --query "[?tags.environment && tags.environment == '$ENV_NAME'].loginServer" -otsv)
AKS_OIDC_ISSUER="$(az aks show --resource-group ${AKS_RESOURCE_GROUP} \
    --name ${AKS_CLUSTER_NAME} --query "oidcIssuerProfile.issuerUrl" -o tsv)"
AKS_POD_CIDR="$(az aks show -g $AKS_RESOURCE_GROUP -n $AKS_CLUSTER_NAME \
    --query networkProfile.podCidr -o tsv)"

USER_ASSIGNED_CLIENT_ID="$(az identity show -g ${PROCESSING_RESOURCE_GROUP} \
    --name $UAMI --query 'clientId' -o tsv)"
IDENTITY_TENANT=$(az aks show --name ${AKS_CLUSTER_NAME} \
    --resource-group ${PROCESSING_RESOURCE_GROUP} --query identity.tenantId -o tsv)

az identity federated-credential create --name ${FEDERATED_IDENTITY_NAME} \
    --identity-name $UAMI \
    --resource-group ${PROCESSING_RESOURCE_GROUP} \
    --issuer ${AKS_OIDC_ISSUER} \
    --subject system:serviceaccount:${AKS_NAMESPACE}:${AKS_SERVICE_ACCOUNT_NAME} \
    -o none

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

INGRESS_PUBLIC_IP_ADDR=$(az network public-ip show -g $PROCESSING_RESOURCE_GROUP \
    -n ${ENV_CODE}-stac-ingress-public-ip --query ipAddress -o tsv)
INGRESS_FQDN=$(az network public-ip show -g $PROCESSING_RESOURCE_GROUP -n ${ENV_CODE}-stac-ingress-public-ip \
    --query dnsSettings.fqdn -o tsv)
DNS_LABEL_NAME=${INGRESS_FQDN%%.*}

set +a

echo 'enabling POSTGIS,BTREE_GIST in postgres'
az postgres flexible-server \
    parameter set \
    --resource-group $DATA_RESOURCE_GROUP --server-name $PGHOSTONLY \
    --subscription $SUBSCRIPTION --name azure.extensions --value POSTGIS,BTREE_GIST \
    -o none

az aks get-credentials --admin --resource-group ${AKS_RESOURCE_GROUP} \
  --name ${AKS_CLUSTER_NAME} --context ${AKS_CLUSTER_NAME} --overwrite-existing \
  -o none
kubectl config set-context ${AKS_CLUSTER_NAME}

NS=$(kubectl get namespace $AKS_NAMESPACE --ignore-not-found);
if [[ "$NS" ]]; then
    echo "Skipping creation of ${AKS_NAMESPACE} namespace in k8s cluster as it already exists"
else
    echo "Creating ${AKS_NAMESPACE} namespace in k8s cluster"
    kubectl create namespace ${AKS_NAMESPACE}
fi;

echo "Install KEDA"
helm repo add kedacore https://kedacore.github.io/charts || true
helm repo update
[[ -z "$(kubectl get namespace keda --ignore-not-found)" ]] && kubectl create namespace keda
helm upgrade --install keda kedacore/keda --namespace keda

# Deploy a dummy workload to work around issue https://github.com/kedacore/keda/issues/4224
cat <<"EOF" | kubectl apply -n keda -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dummy-workload
spec:
  replicas: 0
  selector:
    matchLabels:
      app: dummy-workload
  template:
    metadata:
      labels:
        app: dummy-workload
    spec:
      containers:
      - name: dummy
        image: busybox
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: dummy-workload
spec:
  scaleTargetRef:
    name: dummy-workload
  minReplicaCount: 0
  maxReplicaCount: 1
  triggers:
  - type: cron
    metadata:
      timezone: Etc/UTC 
      start: 30 * * * *
      end: 45 * * * *
      desiredReplicas: "0"
EOF
kubectl -n keda wait --for=condition=Ready ScaledObject/dummy-workload --timeout=3m
sleep 10

echo "Deploying stac-scaler chart to Kubernetes Cluster"

helm upgrade --install stac-scaler ${PRJ_ROOT}/deploy/helm/stac-scaler \
    --namespace ${AKS_NAMESPACE} \
    --create-namespace \
    --set envCode=${ENV_CODE} \
    --set repository=${ACR_DNS} \
    --set userAssignedClientId=${USER_ASSIGNED_CLIENT_ID} \
    --set serviceAccountName=${AKS_SERVICE_ACCOUNT_NAME} \
    --set keyVaultName=${KEY_VAULT_NAME} \
    --set tenantId=${IDENTITY_TENANT} \
    --set processors.staccollection.env.DATA_STORAGE_ACCOUNT_NAME=${DATA_STORAGE_ACCOUNT_NAME} \
    --set processors.staccollection.env.STACCOLLECTION_STORAGE_CONTAINER_NAME=${STACCOLLECTION_STORAGE_CONTAINER_NAME} \
    --set processors.staccollection.env.PGHOST=${PGHOST} \
    --set processors.staccollection.env.PGUSER=${PGUSER} \
    --set processors.staccollection.env.PGDATABASE=${PGDATABASE} \
    --set processors.staceventconsumer.env.DATA_STORAGE_ACCOUNT_NAME=${DATA_STORAGE_ACCOUNT_NAME} \
    --set processors.staceventconsumer.env.GENERATED_STAC_STORAGE_CONTAINER_NAME=${GENERATED_STAC_STORAGE_CONTAINER_NAME} \
    --set processors.staceventconsumer.env.DATA_STORAGE_PGSTAC_CONTAINER_NAME=${DATA_STORAGE_PGSTAC_CONTAINER_NAME} \
    --set processors.staceventconsumer.env.PGHOST=${PGHOST} \
    --set processors.staceventconsumer.env.PGUSER=${PGUSER} \
    --set processors.staceventconsumer.env.PGDATABASE=${PGDATABASE} \
    --set processors.generatestacjson.env.DATA_STORAGE_ACCOUNT_NAME=${DATA_STORAGE_ACCOUNT_NAME} \
    --set processors.generatestacjson.env.STACIFY_STORAGE_CONTAINER_NAME=${STACIFY_STORAGE_CONTAINER_NAME} \
    --set processors.generatestacjson.env.GENERATED_STAC_STORAGE_CONTAINER_NAME=${GENERATED_STAC_STORAGE_CONTAINER_NAME} \
    --set processors.generatestacjson.env.DATA_STORAGE_PGSTAC_CONTAINER_NAME=${DATA_STORAGE_PGSTAC_CONTAINER_NAME} \
    --set processors.generatestacjson.env.STAC_METADATA_TYPE_NAME=${STAC_METADATA_TYPE_NAME} \
    --set stacfastapi.image.repository=${ACR_DNS} \
    --set stacfastapi.env.POSTGRES_HOST_READER=${PGHOST} \
    --set stacfastapi.env.POSTGRES_HOST_WRITER=${PGHOST} \
    --set stacfastapi.env.POSTGRES_USER=${PGUSER} \
    --set stacfastapi.env.PGUSER=${PGUSER} \
    --set stacfastapi.env.PGHOST=${PGHOST} \
    --set stacfastapi.blobStoreEndpoint=${DATA_STORAGE_ACCOUNT_BLOB_ENDPOINT} \
    --set stacfastapi.hostname=${INGRESS_FQDN} \
    --set stacfastapi.clusterIssuer=letsencrypt

echo "Deploying stac-browser chart to Kubernetes Cluster"

helm upgrade --install stac-browser ${PRJ_ROOT}/deploy/helm/stac-browser \
    --namespace ${AKS_NAMESPACE} \
    --create-namespace \
    --set envCode=${ENV_CODE} \
    --set repository=${ACR_DNS} \
    --set hostname=${INGRESS_FQDN} \
    --set clusterIssuer=letsencrypt

# Add helm repos for the nginx ingress controller and cert-manager
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install the cert-manager Helm chart (for letsencrypt certificates)
echo "Installing cert-manager"
kubectl create namespace $AKS_INGRESS_NAMESPACE
kubectl label namespace $AKS_INGRESS_NAMESPACE cert-manager.io/disable-validation=true
helm upgrade --install cert-manager jetstack/cert-manager \
  --create-namespace \
  --namespace $AKS_INGRESS_NAMESPACE \
  --set installCRDs=true \
  --set nodeSelector."kubernetes\.io/os"=linux

# Create a ClusterIssuer to issue certificates from Lets Encrypt
cat <<EOF | kubectl apply -n $AKS_INGRESS_NAMESPACE -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $LE_EMAIL_ADDRESS
    privateKeySecretRef:
      name: letsencrypt-private-key
    solvers:
    - http01:
        ingress:
          class: nginx
          podTemplate:
            spec:
              nodeSelector:
                "kubernetes.io/os": linux
EOF


# Wait for the cert-manager pods to be ready
echo "Waiting for cert-manager deployment to be ready..."
kubectl -n $AKS_INGRESS_NAMESPACE wait --timeout=5m \
    --for=condition=Ready pod \
    --selector=app.kubernetes.io/name=cert-manager

# Create a long-lived SAS token for reading from the storage account and store it in keyvault.
# The nginx ingress controller will use this for accessing the storage account via proxy
# by appending the SAS token to the URL when sending to the backend server.
SAS_TOKEN=$(az storage account generate-sas \
    --resource-types sco --services b --permissions flpr \
    --expiry "2037-12-31T23:59Z" \
    --https-only \
    --account-name $DATA_STORAGE_ACCOUNT_NAME \
    --account-key $DATA_STORAGE_ACCOUNT_KEY \
    -otsv)
az keyvault secret set \
    --vault-name $KEY_VAULT_NAME \
    --name StorageAccountReadSASToken \
    --value $SAS_TOKEN \
    -o none

##
## Install the nginx ingress controller, configured with the CSI secret store
## driver to access the Azure Storage Account SAS token.
##

# Create a secret provider to access the Azure Storage Account SAS token
cat <<EOF | kubectl apply -n $AKS_INGRESS_NAMESPACE -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: k8s-nginx-ingress-secrets
spec:
  provider: azure
  secretObjects:
  - secretName: azure-secrets
    type: Opaque
    data:
    - key: StorageAccountReadSASToken
      objectName: StorageAccountReadSASToken
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "false"
    # The client ID of the user-assigned managed identity or application that is
    # used for workload identity, and to access the keyvault.
    clientID: $USER_ASSIGNED_CLIENT_ID
    keyvaultName: $KEY_VAULT_NAME
    tenantID: $IDENTITY_TENANT
    cloudName: $(az cloud show --query name -otsv)
    objects:  |
      array:
        - |
          objectName: StorageAccountReadSASToken
          objectType: secret
EOF

RELEASE_NAME=ingress-nginx

# Create the credential to allow the ingress controller to use the managed identity
# to access secrets in the keyvault.
echo "Creating a federated credential for the ingress controller to access the managed identity $UAMI"
az identity federated-credential create --name nginx-ingress-access-$AKS_NAME \
    --identity-name $UAMI \
    --resource-group $PROCESSING_RESOURCE_GROUP \
    --issuer $AKS_OIDC_ISSUER \
    --subject system:serviceaccount:$AKS_INGRESS_NAMESPACE:$RELEASE_NAME \
    -o none

helm upgrade --install $RELEASE_NAME ingress-nginx/ingress-nginx \
    --namespace $AKS_INGRESS_NAMESPACE \
    --create-namespace \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
    --set serviceAccount.annotations."azure\.workload\.identity/client-id"=$USER_ASSIGNED_CLIENT_ID \
    --set controller.config.proxy-buffer-size=32k \
    --set controller.config.main-snippet="env STORAGE_SAS_TOKEN;" \
    --set controller.config.http-snippet="geo \$internal_user { $AKS_POD_CIDR 1; }" \
    --set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/os"=linux \
    --set controller.service.externalTrafficPolicy=Local \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-resource-group"="$PROCESSING_RESOURCE_GROUP" \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-dns-label-name"="$DNS_LABEL_NAME" \
    --set controller.service.loadBalancerIP=$INGRESS_PUBLIC_IP_ADDR \
    --set controller.image.repository=mcr.microsoft.com/oss/kubernetes/ingress/nginx-ingress-controller \
    --set controller.image.tag=v1.7.0-3 \
    --set controller.image.digest=sha256:29ad700988b2dd3e7b9b130c2625f24d5b5eae7420e3dfd6dee579a730ecbb1c \
    --set "controller.extraVolumeMounts[0].name=secrets-store-inline" \
    --set "controller.extraVolumeMounts[0].mountPath=/mnt/secrets-store" \
    --set "controller.extraVolumeMounts[0].readOnly=true" \
    --set "controller.extraVolumes[0].name=secrets-store-inline" \
    --set "controller.extraVolumes[0].csi.driver=secrets-store.csi.k8s.io" \
    --set "controller.extraVolumes[0].csi.readOnly=true" \
    --set "controller.extraVolumes[0].csi.volumeAttributes.secretProviderClass=k8s-nginx-ingress-secrets" \
    --set "controller.extraEnvs[0].name=STORAGE_SAS_TOKEN" \
    --set "controller.extraEnvs[0].valueFrom.secretKeyRef.name=azure-secrets" \
    --set "controller.extraEnvs[0].valueFrom.secretKeyRef.key=StorageAccountReadSASToken"

# Helm creates the service account, but there's no way to add the label we need to it.
# Add that manually after the fact.
kubectl label -n $AKS_INGRESS_NAMESPACE sa/$RELEASE_NAME azure.workload.identity/use="true"

# Wait for the ingress controller to be ready
echo "Waiting for ingress controller to be ready..."
kubectl -n $AKS_INGRESS_NAMESPACE wait --timeout=5m \
    --for=condition=Ready pod \
    --selector=app.kubernetes.io/name=$RELEASE_NAME

# Deploy the ingress for the blob store proxy that forwards requests
# to storage with a SAS token appended.
cat <<EOF | kubectl -n $AKS_NAMESPACE apply -f -
---
kind: Service
apiVersion: v1
metadata:
  name: blobstore-proxy
spec:
  type: ExternalName
  externalName: $DATA_STORAGE_ACCOUNT_BLOB_DOMAIN
  ports:
  - port: 443
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: blobstore-proxy
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /\$1
    nginx.ingress.kubernetes.io/proxy-request-buffering: "off"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/upstream-vhost: "$DATA_STORAGE_ACCOUNT_BLOB_DOMAIN"
    # Rewrite URI to include SAS token (note, the query separator has to be
    # in the rewrite statement, and not as part of the SAS token)
    # TODO: handle URLs that might already have a query string
    nginx.ingress.kubernetes.io/configuration-snippet: |
      proxy_cache off;
      rewrite (.*) \$1?\$storage_sas_token;
    # Reads the SAS token from the STORAGE_SAS_TOKEN environment variable and
    # sets as an nginx variable so we can use it in the rewrite statement. Note
    # that this relies on the server configmap containing a main-snippet with an
    # "env STORAGE_SAS_TOKEN" statement to ensure nginx inherits that env variable
    # from its parent.
    nginx.ingress.kubernetes.io/server-snippet: |
      set_by_lua_block \$storage_sas_token { return os.getenv("STORAGE_SAS_TOKEN") }
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - $INGRESS_FQDN
    secretName: stac-certificate
  rules:
  - host: $INGRESS_FQDN
    http:
      paths:
      - path: /blobstore/(.*)
        pathType: Prefix
        backend:
          service:
            name: blobstore-proxy
            port:
              number: 443
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: stac-browser
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /\$2
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - $INGRESS_FQDN
    secretName: stac-certificate
  rules:
  - host: $INGRESS_FQDN
    http:
      paths:
      - path: /browser(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: stac-browser
            port:
              number: 8082
EOF

# Deploy the auth proxy if selected
[[ -n "$SECURE_STAC_ENDPOINTS" ]] && $PRJ_ROOT/deploy/scripts/secure-stac-endpoints.sh

cat <<EOF



**** The STAC API is available at: https://$INGRESS_FQDN/api/
The TLS certificate may not have been issued yet, so you may see a warning in your browser.
If you wish to wait, you can run the following command to wait until the certificate is ready:
  kubectl -n $AKS_NAMESPACE wait --timeout=10m --for=condition=Ready certificate stac-certificate

If this command times out, then it is possible there was an error with cert generation. You can
inspect the cert-manager logs to see if there was an error:
  kubectl -n $AKS_INGRESS_NAMESPACE logs -l app=cert-manager
EOF
