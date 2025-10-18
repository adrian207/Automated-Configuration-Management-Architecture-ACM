# Azure Module Variables
# Author: Adrian Johnson <adrian207@gmail.com>

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be dev, test, or prod."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for VNet"
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "subnet_management" {
  description = "Management tier subnet"
  type        = string
  default     = "10.10.10.0/24"
}

variable "subnet_monitoring" {
  description = "Monitoring tier subnet"
  type        = string
  default     = "10.10.20.0/24"
}

variable "subnet_data" {
  description = "Data tier subnet"
  type        = string
  default     = "10.10.30.0/24"
}

variable "subnet_nodes" {
  description = "Managed nodes subnet"
  type        = string
  default     = "10.10.100.0/22"
}

variable "vm_size_dsc" {
  description = "VM size for DSC pull servers"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "vm_size_vault" {
  description = "VM size for Vault servers"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "vm_size_monitoring" {
  description = "VM size for monitoring servers"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "vault_node_count" {
  description = "Number of Vault cluster nodes"
  type        = number
  default     = 3
  validation {
    condition     = var.vault_node_count >= 3 && var.vault_node_count <= 5
    error_message = "Vault cluster must have 3-5 nodes for HA."
  }
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    project     = "config-management"
    managed_by  = "terraform"
    owner       = "adrian.johnson@contoso.com"
  }
}

variable "enable_backup" {
  description = "Enable Azure Backup for VMs"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable Azure Monitor"
  type        = bool
  default     = true
}


