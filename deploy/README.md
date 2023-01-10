# Deploy and catalog sample data using STAC API

## Deployment

### Prerequisites

The deployment script uses following tools, please follow the links provided to install the suggested tools on your computer using which you would execute the script.

- [az cli](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [bicep](https://docs.microsoft.com/azure/azure-resource-manager/bicep/install)
- [jq](https://stedolan.github.io/jq/download/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
- [helm](https://helm.sh/)
- [wget](https://www.jcchouinard.com/wget/)

- The scripts are executed on bash shell, so if using a computer with windows based operating system, install a [WSL](https://docs.microsoft.com/windows/wsl/about) environment to execute the script.
- The bicep templates have been written to adhere to the syntax and rules for bicep version >= 0.8.2. Please check your bicep version using `az bicep version` or `bicep --version` if you run into bicep related errors.

>[!NOTE]
The solution uses Azure AD workload identity (preview). Please ensure the following additional pre-requisites are also satisfied:
- az cli version 2.40.0 or later
- Installed the latest version of the aks-preview extension, version 0.5.102 or later. 
- Existing Azure Subscription with EnableWorkloadIdentityPreview feature enabled
- Existing AKS cluster with enable-oidc-issuer and enable-workload-identity enabled

#### RBAC requirement

The user performing the deployment of the bicep template and the associated scripts should have `Owner` role assigned at the subscription to which the resources are being deployed. This is needed in order to grant IAM roles to managed identities in bicep templates.

> [!NOTE]
If you have started the deployment with a different role Ex: `Contributor`, and the deployment failed due to insufficient access. Please change the role to `Owner` and refresh the credentials by re-logging before attempting to deploy again.

### How does the scripts work?

- `setup.sh`: This wrapper script calls the underlying deployment task scripts one by one. First, it invokes the infrastructure deployment script, build docker images, and then deploy container applications to the infrastructure.
- `install.sh`: This shell script runs an `az bicep` command to invoke `bicep` tool. This command recieves the bicep template as input, and converts the bicep templates into an intermediate ARM template output which is then submitted to Azure APIs to create the Azure resources.
- `build.sh`: This script invokes `az acr build` to pack the source code, upload to, and build the docker images in the ACR, setup by `install.sh`.
- `configure.sh`: This script retrieves the azure resource names, credentials, and connection strings from the infrastructure provisioned & its key vault, and invoke `kubectl apply` to deploy container applications.

**For instructions on deploying & configuring the solution, please visit [here](../docs/deploying-infra.md).**

## Cataloging sample data

By default, the public access to the infrastructure is disabled and you may need to SSH to the jumpbox vm through [Azure bastion](../docs/using-bastion-for-ssh.md) and initiate blob file copy operation as a preparation to the [Cataloging process](../docs/cataloging-sample-data.md). You may find the jumpbox under `<environmentCode>-processing-rg` resource group, select the VM, click `Connect` and SSH using the `Bastion` tab.

Additionally, you may need to access the Key Vault for reading the secrets (for ex: Postgres database, Storage accounts etc). As this is a fully secured environment access to Key Vault can be allowed only from the jumpbox-vnet. Follow the [steps](../docs/accessing-keyvault.md).
