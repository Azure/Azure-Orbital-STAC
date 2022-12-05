# STAC-FastAPI Deployment on AKS

This folder includes a deployment template for STAC_FASTAPI on AKS connected to Azure Postgres Flexible Server.

- Create Infrastructure using bicep. For details, please go to the deployment folder [here](/deploy/README.md)

- Build and deploy docker images to ACR by running [build.sh](/deploy/scripts/build.sh). This script will build & deploy stac-fastapi and other docker images in ACR. stac-fastapi docker image source is from <https://github.com/stac-utils/stac-fastapi> V2.3.0 repository

- Deploy STAC_FASTAPI and others to your infrastruxcture by running [configure.sh](/deploy/scripts/configure.sh). As a pre-requisite, whitelisting required extensions will be invoked.

    ```bash
    az postgres flexible-server parameter set --resource-group $RG --server-name $PGNAME --subscription $SUBSCRIPTION --name azure.extensions --value POSTGIS,BTREE_GIST
    ```

    And, then it will inject environment variables to the template file app-stacfastapi-deployment.tpl.yaml and deploy to AKS.

    ```bash
    envsubst < ${PRJ_ROOT}/src/stac_fastapi_k8s/app-stacfastapi-deployment.tpl.yaml | kubectl -n $AKS_NAMESPACE apply -f -
    ```

- Ingest Data in PostgreSQL using ingestion mechanism.

- If your AKS Deployment is located in a non-production Azure Subscription in Microsoft tenant, you may not be able to access the Kubernetes Service on its public IP from internet. You will need to be physically connected to CORPNET (as this is required by Simply Secure V2 Rules) or deploy in non-ms tenant.
