variable "prefix" {
  type = string
  default = "blue"
}

variable "env" {
  default = "blue"
  description="Used as part of naming the VM"
}

variable "subscription" {
  type      = string
  sensitive = true
}

variable "tenant" {
  type      = string
  sensitive = true
}

variable "firewall_allow_ports" {
  default = {
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
    }
}

variable "public_key_path"{
  type      = string
  description = "Path of the SSH public key used to authenticate to a virtual machine through ssh. the provided public key needs to be at least 2048-bit and in ssh-rsa format"
}

variable "location"{
  type        = string
  description = "Location the resource will be deployed"
  default     = "Australia Southeast" # Victoria
}

variable "admin_user"{
  type        = string
  description = "User ID to be created for the admin user"
  default     = "admin" 
}

