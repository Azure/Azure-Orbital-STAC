#!/usr/bin/env bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

PRJ_ROOT="$(cd `dirname "${BASH_SOURCE}"`/../..; pwd)"
ENV_CODE=${1:-${ENV_CODE}}
AKS_NAMESPACE=${AKS_NAMESPACE:-"pgstac"}
AKS_INGRESS_NAMESPACE=${AKS_INGRESS_NAMESPACE:-"ingress"}

[[ -z "$ENV_CODE" ]] && { echo "Environment Code value not supplied"; exit 1; }

set -a
set -e
echo "Retrieving required properties from Azure resources."
PROCESSING_RESOURCE_GROUP=${PROCESSING_RESOURCE_GROUP:-"${ENV_CODE}-processing-rg"}
AAD_ENDPOINT=$(az cloud show --query endpoints.activeDirectory -otsv)
TENANT_ID=$(az account show --query tenantId -otsv)

# Retrieve the public IP address we created in the deployment
FQDN=$(az network public-ip show -g $PROCESSING_RESOURCE_GROUP \
  -n ${ENV_CODE}-stac-ingress-public-ip --query dnsSettings.fqdn -o tsv)
DNS_DOMAIN=${FQDN#*.}

# Create an Azure AD application to perform authentication on the STAC endpoints
echo "Creating Azure AD application to secure the STAC endpoints"
APP_ID=$(az ad app create \
  --display-name "STAC Endpoints for $ENV_CODE" \
  --sign-in-audience AzureADMyOrg \
  --web-redirect-uris "https://$FQDN/oauth2/callback" \
  --optional-claims @$PRJ_ROOT/deploy/data/claims.json \
  --required-resource-accesses @$PRJ_ROOT/deploy/data/resource_access.json \
  --app-roles @$PRJ_ROOT/deploy/data/roles.json \
  --query "appId" -otsv)
# Generate a password for the app
APP_PW=$(az ad app credential reset \
  --id $APP_ID \
  --append \
  --display-name "oauth2-proxy access for STAC endpoints on $(az account show --query name -otsv)" \
  --query "password" -otsv)

helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests || true
helm repo update

# Install the oauth2-proxy Helm chart
echo "Installing the oauth2-proxy Helm chart"
AKS_RESOURCE_GROUP=${AKS_RESOURCE_GROUP:-${PROCESSING_RESOURCE_GROUP}}
AKS_CLUSTER_NAME=$(az aks list -g ${AKS_RESOURCE_GROUP} --query "[?tags.type && tags.type == 'k8s'].name" -otsv)
AKS_ISSUER_URL=$(az aks show --resource-group $AKS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME --query oidcIssuerProfile.issuerUrl -otsv)
OAUTH_PROXY_VALUES_FILE=$(mktemp -t oauth2-proxy-values)
trap 'rm -f -- "$OAUTH_PROXY_VALUES_FILE"' EXIT
cat > $OAUTH_PROXY_VALUES_FILE <<EOF
replicaCount: 2
config:
  clientID: $APP_ID
  clientSecret: $APP_PW
  cookieSecret: $(openssl rand -base64 32 | tr -- '+/' '-_')

ingress:
  enabled: true
  className: nginx
  path: /oauth2
  pathType: Prefix
  hosts:
    - $FQDN
  tls:
    - hosts:
        - $FQDN
      secretName: stac-certificate
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt

extraArgs:
  provider: oidc
  oidc-issuer-url: $AAD_ENDPOINT/$TENANT_ID/v2.0
  # Use the next two lines instead to support multi-tenant authentication.
  # Note that if a tenant does not include an e-mail address in the payload
  # returned by authentication, then oauth2-proxy will fail to authenticate.
  # oidc-issuer-url: $AAD_ENDPOINT/common/v2.0
  # insecure-oidc-skip-issuer-verification: true
  code-challenge-method: S256
  # AAD doesn't always return an e-mail address in the email claim. Use
  # the preferred_username field as it seems to be present in most cases.
  # If this claim is missing, authentication will fail.
  oidc-email-claim: preferred_username
  # Look for "groups" in the roles claim, in case we assigned app roles
  # to the user.
  oidc-groups-claim: roles
  cookie-refresh: 10m
  cookie-expire: 15m
  cookie-domain: .$DNS_DOMAIN
  # Pass authentication information to the nginx ingress controller
  pass-access-token: true
  set-xauthrequest: true
  set-authorization-header: true
  silence-ping-logging: true
  whitelist-domain: .$FQDN
  scope: openid email profile
  # Allow authentication from a JWT Bearer token. Only token issued
  # by the issuers listed in oidc-issuer-url and extra-jwt-issuers will
  # be trusted. The aud claim must also match the right-hand side of the
  # pair in extra-jwt-issuers. In this case, we're trusting tokens issued
  # by the AKS cluster and the Azure AD app we created above.
  skip-jwt-bearer-tokens: true
  extra-jwt-issuers: "$AKS_ISSUER_URL=$AKS_ISSUER_URL,$AAD_ENDPOINT/$TENANT_ID/v2.0=$APP_ID"
  show-debug-on-error: true
  ##
  ## Authorization limits. You can limit authorization to certain groups
  ## and/or e-mail domains.
  ##
  # Change this if you want to limit access to certain e-mail domains.
  email-domain: "*"
  # Uncomment to limit access to certain groups
  #allowed-group: "STAC.Read,STAC.Write"

service:
  portNumber: 4180

nodeSelector:
  kubernetes.io/os: linux
EOF

helm upgrade --install oauth2-proxy oauth2-proxy/oauth2-proxy \
    --create-namespace \
    --namespace $AKS_INGRESS_NAMESPACE \
    -f $OAUTH_PROXY_VALUES_FILE
rm -f $OAUTH_PROXY_VALUES_FILE

echo "Waiting for oauth2-proxy deployment to be ready"
kubectl -n $AKS_INGRESS_NAMESPACE wait --for=condition=Ready pod \
  -l app.kubernetes.io/name=oauth2-proxy --timeout=5m

# Apply annotations to enable auth on the STAC endpoints
kubectl -n $AKS_NAMESPACE annotate ingress stac-browser \
    nginx.ingress.kubernetes.io/auth-url='https://$host/oauth2/auth' \
    nginx.ingress.kubernetes.io/auth-signin='https://$host/oauth2/start?rd=$escaped_request_uri'
kubectl -n $AKS_NAMESPACE annotate ingress fast-stac-api \
    nginx.ingress.kubernetes.io/auth-url='https://$host/oauth2/auth' \
    nginx.ingress.kubernetes.io/auth-signin='https://$host/oauth2/start?rd=$escaped_request_uri'
kubectl -n $AKS_NAMESPACE annotate ingress blobstore-proxy \
    nginx.ingress.kubernetes.io/auth-url='https://$host/oauth2/auth' \
    nginx.ingress.kubernetes.io/auth-signin='https://$host/oauth2/start?rd=$escaped_request_uri'
kubectl -n $AKS_NAMESPACE annotate ingress blobstore-proxy nginx.ingress.kubernetes.io/auth-snippet='
  # Allow internal requests to bypass auth. $internal_user is set up when the
  # chart is deployed using the main-snippet value in the configmap. The variable
  # is true if the caller IP is in the k8s cluster pod cidr range.
  if ($internal_user) {
    return 200;
  }'
