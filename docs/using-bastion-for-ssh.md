# Using Bastion for SSH to Jumpbox

This deployment includes a Jumpbox (Azure Virtual Machine) that will serve as the secure way to interact with the workload. The intend of this jumpbox is to provide a way to perform activities required for the workload:

- Copying data from and to Storage Accounts inside private subnets
- Copying data from and to Storage Accounts from public subnets
- Access secrets from Key Vault in private subnets

If you have an existing Virtual Network with an existing Jumpbox or an On-premise network connected via S2S VPN or Express route, you may use any device connected to those network to perform the activities listed above. 

Follow the steps below to SSH into the Jumpbox using Bastion:

1. In the Azure Portal, go to the virtual machine that you want to connect to. On the **Overview** page, select **Connect**, then select **Bastion** from the dropdown to open the Bastion connection page. You can also select **Bastion** from the left pane.

2. On the Bastion connection page, click the **Connection Settings** arrow to expand all available settings.

3. Authenticate and connect using Password based Authentication. You can use the [Password - Azure Key Vault](https://docs.microsoft.com/en-us/azure/bastion/bastion-connect-vm-ssh-linux#password---azure-key-vault) approach to directly use your jumpbox password store in Key Vault as Secret.

**Note:** Your Jumpbox SSH password is password in the Key Vault deployed to the `<environment-code>-data-rg` resource group under the name `<jumpbox-name>-Password` secret.