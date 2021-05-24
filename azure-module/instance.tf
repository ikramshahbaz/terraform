provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "resourcegroup" {
  name     = var.rgname
  location = var.location
  tags = var.tags
}

resource "random_integer" "priority" {
  count   = 2
min  = 10
max = 20
}

resource "azurerm_virtual_network" "main_network" {
  name               		 = var.main_network_name
  resource_group_name	 = var.rgname
  location           		 = var.location
  address_space  		= var.main_address_space     
}

resource "azurerm_subnet" "internal_subnet" {
  count                   		 = length(var.internal_subnet_address_space)
#  name                		 = "${var.subnet_name}-${count.index}"
   name  			=  join("-", [var.subnet_name, random_integer.priority[count.index].id])
  resource_group_name  	 = var.rgname
  virtual_network_name	 = azurerm_virtual_network.main_network.name
  address_prefixes                     = [element(var.internal_subnet_address_space, count.index)]
}

resource "azurerm_network_security_group" "security_group" {
  name                		 = var.security_group_name
  location           		 = var.location
  resource_group_name	 = var.rgname

  security_rule {
    name                       = "rule-1"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "security_group_associate" {
  count 		  = length(var.internal_subnet_address_space)
  subnet_id                 = element(azurerm_subnet.internal_subnet.*.id, count.index)
  network_security_group_id = azurerm_network_security_group.security_group.id
}


resource "azurerm_network_interface" "interface_name" {
  count		      =  2
  name                =  "${var.interface_name}-${count.index}"
  location            = var.location
  resource_group_name = var.rgname

  ip_configuration {
    name                          = "${var.ip_name}-${count.index}"
    private_ip_address_allocation = "Dynamic"
    #public_ip_address_id          = azurerm_public_ip.public_ip.id
    subnet_id                     =  element(azurerm_subnet.internal_subnet.*.id, count.index) 
  }
}