# Create a resource group
resource "azurerm_resource_group" "node" {
  name     = "${var.prefix}-${var.env}-resources"
  location = "${var.location}" 
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "node" {
  name                = "${var.prefix}-${var.env}-network"
  resource_group_name = azurerm_resource_group.node.name
  location            = azurerm_resource_group.node.location
  address_space       = ["10.0.0.0/16"]
}

# Create a subnet in the virtual network 
# (A virtual network can have one or more subnets)
resource "azurerm_subnet" "internal" {
  name                 = "${var.prefix}-${var.env}-internal"
  resource_group_name  = azurerm_resource_group.node.name
  virtual_network_name = azurerm_virtual_network.node.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Create a public IP address
resource "azurerm_public_ip" "node" {
  name                = "${var.prefix}-${var.env}-external-ip"
  location            = azurerm_resource_group.node.location
  resource_group_name = azurerm_resource_group.node.name
  allocation_method   = "Dynamic"
}

# Create a NIC to attach to the VM to the public ip
resource "azurerm_network_interface" "node" {
  name                = "${var.prefix}-${var.env}-nic"
  resource_group_name = azurerm_resource_group.node.name
  location            = azurerm_resource_group.node.location

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.node.id
  }
}

# Create a NIC to attach to the VM to the internal ip
resource "azurerm_network_interface" "internal" {
  name                      = "${var.prefix}-${var.env}-nic2"
  resource_group_name       = azurerm_resource_group.node.name
  location                  = azurerm_resource_group.node.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create an NSG to control inbound traffic from the internet  
resource "azurerm_network_security_group" "node" {
  name                = "${var.prefix}_node_nsg"
  location            = azurerm_resource_group.node.location
  resource_group_name = azurerm_resource_group.node.name
}


resource "azurerm_network_security_rule" "node" {
  for_each = var.firewall_allow_ports
  
  name                        = "${var.prefix}-${each.key}"
  priority                    = each.value.priority
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = each.value.port
  source_address_prefix       = "*"
  destination_address_prefix  = azurerm_network_interface.node.private_ip_address
  resource_group_name         = azurerm_resource_group.node.name
  network_security_group_name = azurerm_network_security_group.node.name
}

# Associate the network interface to an nsg (NSGs can also be associated to subnets and rules would apply to all VMs hosted on the subnet)
resource "azurerm_network_interface_security_group_association" "node" {
  network_interface_id      = azurerm_network_interface.node.id
  network_security_group_id = azurerm_network_security_group.node.id
}

resource "azurerm_linux_virtual_machine" "node" {
  name                = "${var.prefix}-node-${var.env}"
  resource_group_name = azurerm_resource_group.node.name
  location            = azurerm_resource_group.node.location
  size                = "Standard_D8ds_v4" # https://learn.microsoft.com/en-us/azure/virtual-machines/ddv4-ddsv4-series
  admin_username      = "${var.admin_user}"
  network_interface_ids = [
    azurerm_network_interface.node.id,
  ]

  admin_ssh_key {
    username   = "${var.admin_user}"
    public_key = file("${var.public_key_path}")
  }

  os_disk {
    name                 = "${var.prefix}-${var.env}-os-disk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         =  "512" 
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

output "next_steps" {
  value = "Please update the speed of the OS Disk of node manually in the Azure Portal. Ignore this message if not applicable"
}
