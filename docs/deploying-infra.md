# Overview of deployment and configuration

The script requires following input

- `environmentCode` which serves as the prefix for infrastructure services names. Allows only alpha numeric(no special characters) and must be between 3 and 8 characters.
- `location` which suggests which azure region infrastructure is deployed in.
- `jumpboxPassword` through which users will SSH into Azure VM. The supplied password must be between 6-72 characters long
and must satisfy at least 3 out of 4 of the following:
  - Lowercase characters
  - Uppercase characters
  - Numbers (0-9)
  - Special characters (except Control characters)

The deployment involves the following steps outlined below:

No | Step | Duration (approx.) | Required / Optional
---|------|----------|---------------------
1 | Deployment of Infrastructure using bicep template | 60 minutes | required
2 | Building Docker images | 20 minutes | optional
3 | Configuring and Deploying container applications | 5 minutes | required

## Deployment & Configurations

STAC solution is supported on multiple Azure clouds. If you work across different regions or use [Azure Stack](https://learn.microsoft.com/azure-stack/user/?view=azs-2206), you may need to use more than one cloud.

To get the active cloud and a list of all the available clouds:

```azurecli
az cloud list --output table
```

```output
IsActive    Name               Profile
----------  -----------------  ---------
True        AzureCloud         latest
False       AzureChinaCloud    latest
False       AzureUSGovernment  latest
False       AzureGermanCloud   latest
```
The currently active cloud has `True` in the `IsActive` column. Only one cloud can be active at any time.

To switch to one of the national clouds Ex: AzureUSGovernment

```azurecli
az cloud set --name AzureUSGovernment
```

```output
Switched active cloud to 'AzureUSGovernment'.
Active subscription switched to <'subscription name' (subscription id)>.
```

**NOTE**
If your authentication for the activated cloud has expired, you need to re-authenticate before performing any other CLI tasks. If this is your first time switching to the new cloud, you also need to set the active subscription.

(Optional) Login to azure as shown below and set the correct subscription in which you want to provision the resources. 

```azurecli
az login
az account set -s <subscription_id>
```

For end-to-end deployment, you can either choose to run the `setup.sh` script that will take care of deploying all the services, building the docker images and configuring the variables or run the scripts individually as shown below.

Note: For US Government Cloud, 

* set `APIM_PLATFORM_VERSION` to 'stv1' as 'stv2' is not supported. 
* set `POSTGRES_PRIVATE_ENDPOINT_DISABLED` to true as Private EndPoint for PostgreSQL are not supported.

You can make the above changes by settings the environment variables using the commands below.

```bash
export APIM_PLATFORM_VERSION=stv1
export POSTGRES_PRIVATE_ENDPOINT_DISABLED=true
```

```bash

./deploy/scripts/setup.sh <environmentCode> <location> <jumpboxPassword>
```



OR

1. Deployment of Infrastructure using bicep template.

   This step will provision all the required Azure resources.

   ```bash
   ./deploy/scripts/install.sh <environmentCode> <location> <jumpboxPassword>
    ```

   For eg.

    ```bash
   ./deploy/scripts/install.sh stac1 westus3 "<your-password>"
    ```

   Default values for the parameters are provided in the script itself.

   Arguments | Required | Type | Sample value
   ----------|-----------|-------|------------
   environmentCode | yes | string | stac1
   location | yes | string | westus3
   jumpboxPassword | yes | string | Jump@123

2. Building Docker images

   In this step, Docker images such as stac-event-consumer, generate-stac-json, stac-collection, and stac-fastapi will be built and deployed to ACR (Azure Container Registry).

   ```bash
   ./deploy/scripts/build.sh <environmentCode>
   ```

3. Configuring and Deploying container applications

   This step collects the required configuration variables from the infrastructure, and passes them to kubectl deployment specification.

   ```bash
   ./deploy/scripts/configure.sh <environmentCode>
   ```

## Cleanup Script

   Run the below script to clean up the Azure resources provisioned as part of the deployment. The script uses `environmentCode` to identify and remove the services.

   ```bash
   ./deploy/scripts/cleanup.sh <environmentCode>
   ```
