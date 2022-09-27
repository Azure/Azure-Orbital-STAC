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
1 | Preparing to execute the script | 1 minute | required
2 | Deployment of Infrastructure using bicep template | 60 minutes | required
3 | Building Docker images | 20 minutes | optional
4 | Configuring and Deploying container applications | 5 minutes | required

Steps 2 through 4 can instead be deployed using a single script as shown below:

```bash
./deploy/scripts/setup.sh <environmentCode> <location> <jumpboxPassword>
```

## Preparing to execute the script

Before executing the script one would need to login to azure using `az` cli and set the correct subscription in which they want to provision the resources.

```bash
az login
az account set -s <subscription_id>
```

## Deployment of Infrastructure using bicep template

If you have deployed the solution using `setup.sh` script, you should skip this step. However, if you have not run the `setup.sh` script, the steps outlined in this section are required.

To install infrastructure execute `install.sh` script as follows

```bash
./deploy/scripts/install.sh <environmentCode> <location> <jumpboxPassword>
```

Default values for the parameters are provided in the script itself.

Arguments | Required | Type | Sample value
----------|-----------|-------|------------
environmentCode | yes | string | stac1
location | yes | string | westus3
jumpboxPassword | yes | string | P@ssw0rd@123

For eg.

```bash
./deploy/scripts/install.sh stac1 westus3 "P@ssw0rd@123"
```

## Building Docker images

Docker images need to be built and deployed to the ACR (Azure Container Registry). Top level `setup.sh` would call `build.sh` for initial build and deployment. Aftwards, run `build.sh` script alone by following the syntax below to update docker images (i.e. stac-event-consumer, generate-stac-json, stac-collection, and stac-fastapi):

```bash
./deploy/scripts/build.sh <environmentCode>
```

## Configuring and Deploying container applications

`configure.sh` collects the required configuration variables from the infrastructure, and passes them to kubectl deployment specification. You may run this step as a stand-alone once you complete the initial setup with `setup.sh`.

```bash
./deploy/scripts/configure.sh <environmentCode>
```

## Cleanup Script

We have a cleanup script to cleanup the resource groups and thus the resources provisioned using the `environmentCode`.
As discussed above the `environmentCode` is used as prefix to generate resource group names, so the cleanup-script deletes the resource groups with generated names.

Execute the cleanup script as follows:

```bash
./deploy/scripts/cleanup.sh <environmentCode>
```
