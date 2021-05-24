variable "rgname"  {
	type = string
}

variable "location" {
	type = string
}

variable "tags" {
	type  = map(string)
}

variable "main_network_name" {
	type = string
}

variable "main_address_space" {
	type = list(string)
}

variable "subnet_name" {
	type = string
}

variable "internal_subnet_address_space" {
	type = list(string)
}

variable "security_group_name" {
	type = string
}

variable "interface_name" {
	type = string
}

variable "ip_name" {
	type = string
}








