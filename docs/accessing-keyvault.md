# Accessing Key Vault secrets from Jumpbox

Key Vault is not accessible publicly and is secured to be accessed only from jumpbox-vnet.

One would need to login to azure cli (which is pre-installed on jumpbox) and read the keyvault secrets when needed.

Following are the steps to read the secret from jumpbox

- Login to jumpbox using the bastion provisioned in `<envCode>-processing-rg` resource group

- Login to azure cli
  
    ```bash
    az login --use-device-code
    ```

    This command will provide a token and URL login to azure cli

- Set azure subscription

    ```bash
    az account set -s <subscription-id>
    ```

- Query keyvault secrets

    ```bash
    az keyvault secret list --vault-name <keyvault-name> --query '[].name'
    ```

- Check the value of key Vault secret

    ```bash
    az keyvault secret show --vault-name <keyvault-name> --name <keyvault-secret-name> --query 'value' -o tsv
    ```
