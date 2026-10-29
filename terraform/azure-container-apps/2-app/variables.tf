variable "resource_group_name" {
  type    = string
  default = "rg-azure-test"
}

variable "container_app_environment" {
  type = string
    default = "bluelock-aca-container-app-env"
}

variable "container_app_name" {
  type    = string
  default = "bluelock-container-app"
}

variable "vm_public_ip" {
  description = "Public IP address of the control plane VM."
  type        = string
}