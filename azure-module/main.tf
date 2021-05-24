provider "azurerm" {
  features {}
}

module "instance" {
  source                        = "./instance"
  rgname                        = "terraform-class"
  location                      = "West Europe"
  main_network_name             = "production-network"
  main_address_space            = ["10.0.0.0/16"]
  subnet_name                   = "subnet"
  internal_subnet_address_space = ["10.0.1.0/24", "10.0.2.0/24"]
  security_group_name           = "production-sg"
  interface_name                = "ent"
  ip_name                       = "ent"
  tags = {
    application = "EPIMS"
    environment = "production"
  }
}