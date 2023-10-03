# Radix Node Setup
This terraform project can be used for setting up a new validator node on Azure.  


## Initialise Terraform
Run ```terraform init``` after pulling the repo.  

Then run ```terraform plan``` to show the execution plan.  You need to login to the Azure Client before goigng any further.

If satisified then run ```terraform apply``` to deploy the resources to Azure

## Variables File
Create a new variable definition file in this directory with the filename "terraform.tfvars.json" and add the following
```
{
    "subscription":"<subscription id>",
    "tenant":"<tenent id>",
    "firewall_allow_ports": {
        "SSH_Default": {
            "port": "22",
            "priority": "100"
        },
        "HTTPS": {
            "port": "443",
            "priority": "101"
        },
        "Gossip": {
            "port": "30000",
            "priority": "102"
        },
        "Nginx": {
            "port": "3000",
            "priority": "103"
        },
        "SSH": {
            "port": "9999",
            "priority": "104"
        }
    },
    "env":"blue",
    "public_key_path":"~/.ssh/id_rsa.pub"
    "location": "Australia Southeast",
}
```
Ensure that for the firewall ports each has a unique id for priority


## Azure Client Login
Authenticate using the [Azure CLI](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli) using the command ```az login --tenant <account>.onmicrosoft.com``` .  

You can find details of how to Install the Azure Cli [here](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)

## Resources
- [Azure Virtual Machine References](https://learn.microsoft.com/en-us/azure/virtual-machines/)
- [Azure VM Selector](https://azure.microsoft.com/en-au/pricing/vm-selector/)
- [Find an image](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/cli-ps-findimage)
- [Terraform Azure Linux VM](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine)
- [Terraform Git Example for Azure VM with Public IP](https://github.com/hashicorp/terraform-provider-azurerm/blob/main/examples/virtual-machines/linux/public-ip/main.tf)

## WSL2
If using WSL2 you may receieve errors using AzureRM, when running ```terraform apply```.  

```
Error: Unable to list provider registration status, it is possible that this is due to invalid credentials or the service principal does not have permission to use the Resource Manager API, Azure error: resources.ProvidersClient#List: Failure sending request: StatusCode=0 -- Original Error: context canceled
```

Run this command to bypass the issue with the host resolution  ```sudo bash -c "sed -i '/management.azure.com/d' /etc/hosts" ; sudo bash -c 'echo "$(dig management.azure.com | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}$") management.azure.com" >> /etc/hosts'```

For more details check out the following [post](https://github.com/microsoft/WSL/issues/8022) 
