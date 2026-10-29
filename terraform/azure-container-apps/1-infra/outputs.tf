output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "vm_public_ip" {
  value = azurerm_public_ip.vm.ip_address
}

output "vm_private_ip" {
  value = azurerm_network_interface.vm.private_ip_address
}

output "container_app_environment_id" {
  value = azurerm_container_app_environment.this.id
}

output "container_app_environment_name" {
  value = azurerm_container_app_environment.this.name
}