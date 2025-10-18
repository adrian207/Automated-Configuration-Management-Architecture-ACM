# Azure Module Outputs
# Author: Adrian Johnson <adrian207@gmail.com>

output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.main.name
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "subnet_ids" {
  description = "Map of subnet names to IDs"
  value = {
    management = azurerm_subnet.management.id
    monitoring = azurerm_subnet.monitoring.id
    data       = azurerm_subnet.data.id
    nodes      = azurerm_subnet.nodes.id
  }
}

output "vault_cluster_ips" {
  description = "Private IP addresses of Vault cluster nodes"
  value       = azurerm_network_interface.vault[*].private_ip_address
}

output "vault_cluster_ids" {
  description = "VM IDs of Vault cluster nodes"
  value       = azurerm_linux_virtual_machine.vault[*].id
}

output "prometheus_ip" {
  description = "Private IP address of Prometheus server"
  value       = azurerm_network_interface.prometheus.private_ip_address
}

output "prometheus_vm_id" {
  description = "VM ID of Prometheus server"
  value       = azurerm_linux_virtual_machine.prometheus.id
}

output "grafana_ip" {
  description = "Private IP address of Grafana server"
  value       = azurerm_network_interface.grafana.private_ip_address
}

output "grafana_vm_id" {
  description = "VM ID of Grafana server"
  value       = azurerm_linux_virtual_machine.grafana.id
}

output "key_vault_id" {
  description = "ID of the Azure Key Vault"
  value       = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  description = "URI of the Azure Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "nsg_ids" {
  description = "Map of NSG names to IDs"
  value = {
    management = azurerm_network_security_group.management.id
    monitoring = azurerm_network_security_group.monitoring.id
  }
}


