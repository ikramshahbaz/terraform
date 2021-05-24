provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "resourcegroup" {
  name     = "Terraform"
  location = "westeurope"
  tags = {
    name = "shahbaz"
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "network-metis"
  resource_group_name = "Terraform"
  location            = "westeurope"
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "internal" {
  name                 = "testsubnet"
  resource_group_name  = "Terraform"
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "security_group" {
  name                = "acceptanceTestSecurityGroup1"
  location            = "westeurope"
  resource_group_name = "Terraform"

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}


resource "azurerm_subnet_network_security_group_association" "security_group_associate" {
  subnet_id                 = azurerm_subnet.internal.id
  network_security_group_id = azurerm_network_security_group.security_group.id
}

resource "azurerm_public_ip" "public_ip" {
  name                = "acceptanceTestPublicIp1"
  resource_group_name = "Terraform"
  location            = "westeurope"
  allocation_method   = "Dynamic"

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_interface" "main1" {
  name                = "vm-01-nic"
  location            = "westeurope"
  resource_group_name = "Terraform"

  ip_configuration {
    name                          = "ip-vm-01"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
    subnet_id                     = azurerm_subnet.internal.id
  }
}

resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
output "tls_private_key" {
  value = tls_private_key.example_ssh.private_key_pem
  sensitive = true

}


resource "azurerm_linux_virtual_machine" "main2" {
  name                  = "vm-01"
  location              = "westeurope"
  resource_group_name   = "Terraform"
  network_interface_ids = [azurerm_network_interface.main1.id]
  size                  = "Standard_DS1_v2"
  admin_username        = "testadmin"

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = "testadmin"
    public_key = tls_private_key.example_ssh.public_key_openssh
  }
}

data "azurerm_public_ip" "vm" {
  name                = azurerm_public_ip.public_ip.name
  resource_group_name = azurerm_resource_group.resourcegroup.name
  depends_on          = [azurerm_linux_virtual_machine.main2]
}

output "public_ip_address" {
  value = data.azurerm_public_ip.vm.ip_address
}


resource "null_resource" "privatekey" {

  provisioner "local-exec" {
    command = "echo '${tls_private_key.example_ssh.private_key_pem}' > new.txt"
  }
}

resource "null_resource" "remotefilecopy" {

  provisioner "file" {
    source      = "new.html"
    destination = "/tmp/new.html"
  }

  connection {
    host        = azurerm_public_ip.public_ip.ip_address
    type        = "ssh"
    user        = "testadmin"
    private_key = file("new.txt")
    agent       = "false"
  }
}
