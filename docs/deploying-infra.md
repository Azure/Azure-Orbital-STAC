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

Before executing the script, user needs to login to azure as shown below and set the correct subscription in which they want to provision the resources.

```azurecli
az login
az account set -s <subscription_id>
```

For end-to-end deployment, you can either choose to run the `setup.sh` script that will take care of deploying all the services, building the docker images and configuring the variables or run the scripts individually as shown below.

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
