variable "location" {
  type    = string
  default = "Central India"
}

variable "resource_group_name" {
  type    = string
  default = "rg-azure-test"
}

variable "name_prefix" {
  type    = string
  default = "bluelock-aca"
}

variable "vm_username" {
  type    = string
  default = "testuser"
}

variable "vm_password" {
  type      = string
  default = "password@123"
}

variable "vm_token" {
  type      = string
  sensitive = true
}