

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



resource "azurerm_virtual_machine" "main2" {
  name                             = "vm-01"
  location                         = "westeurope"
  resource_group_name              = "Terraform"
  network_interface_ids            = [azurerm_network_interface.main1.id]
  vm_size                          = "Standard_DS1_v2"
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "vm-01-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    disk_size_gb      = 30
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "vm-01"
    admin_username = "testadmin"
    admin_password = "Password1234"
  }

  os_profile_linux_config {
    disable_password_authentication = false
    ssh_keys {
      path     = "/home/testadmin/.ssh/authorized_keys"
      key_data = file("~/.ssh/id_rsa.pub")
    }
  }
}


data "azurerm_public_ip" "vm" {
  name                = azurerm_public_ip.public_ip.name
  resource_group_name = azurerm_resource_group.resourcegroup.name
  depends_on          = [azurerm_virtual_machine.main2]
}

output "public_ip_address" {
  value = data.azurerm_public_ip.vm.ip_address
}


resource "null_resource" "publicip" {

  provisioner "local-exec" {
    command = "echo '${data.azurerm_public_ip.vm.ip_address}' > new.html"
  }
}

resource "null_resource" "ansible" {

  provisioner "local-exec" {
    command = "ansible-playbook -u testadmin -i '${data.azurerm_public_ip.vm.ip_address}', --private-key '~/.ssh/id_rsa' provision.yml"
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
    private_key = file("~/.ssh/id_rsa")
    agent       = "false"
  }
}


resource "null_resource" "remoteexec" {

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install apache2 -y",
      "sudo systemctl start apache2",
      "sudo cp /tmp/new.html /var/www/html/",
      "sudo systemctl restart apache2"
    ]
  }

  connection {
    host        = azurerm_public_ip.public_ip.ip_address
    type        = "ssh"
    user        = "testadmin"
    private_key = file("~/.ssh/id_rsa")
    agent       = "false"
  }
}

