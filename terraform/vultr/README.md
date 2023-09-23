# Radix Node Setup
This terraform project can be used for setting up a new validator node on Vultr.  

Each resource is configured for the minimum 8 vCPU, 16 GB Ram, 250 GB NVMe SSD & Up to 10 Gbps Bandwidth included per month

## Variables File
Create a new variable definition file in this directory with the filename "terraform.tfvars.json" and add the following
```
{
    "vultr_api_key":"<Vultr API Key>",
    "yellow_region":"<Vultr Region>",
    "firewall_allow_ports": ["22", "443", "30000", "3000", "<SSH Port>"],
    "color":"pink"
}
```

## Vultr Account Setup
Make sure you have enabled access control for your IP address under API usage in your Vultr account.  You can also find your API key in your account settings too

## SSH Key Setup
You need to generate an RSA SSH Key that must be called id_rsa_vultr.  You need to ensure the public key is present in your `~/.ssh` directory.

Instructions for generating a new SSH key can be found [here](https://www.vultr.com/docs/how-do-i-generate-ssh-keys).

## Initialise Terraform
Run ```terraform init``` after pulling the repo.  

Then run ```terraform plan``` to show the execution plan.

If satisified then run ```terraform apply``` to deploy the resources to Vultr