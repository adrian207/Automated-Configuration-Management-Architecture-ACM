# Development Environment Terraform Configuration
# Author: Adrian Johnson <adrian207@gmail.com>

terraform {
  required_version = ">= 1.5.0"
  
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    # key is set via -backend-config in CI/CD
  }
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
  }
}

# Azure Infrastructure Module
module "azure_infrastructure" {
  source = "../../modules/azure"
  
  environment          = "dev"
  location             = var.location
  resource_group_name  = "rg-dev-configmgmt"
  vnet_address_space   = ["10.10.0.0/16"]
  subnet_management    = "10.10.10.0/24"
  subnet_monitoring    = "10.10.20.0/24"
  subnet_data          = "10.10.30.0/24"
  subnet_nodes         = "10.10.100.0/22"
  
  vault_node_count     = 3
  vm_size_vault        = "Standard_D2s_v3"
  vm_size_monitoring   = "Standard_D2s_v3"
  
  admin_username       = var.admin_username
  ssh_public_key_path  = var.ssh_public_key_path
  
  enable_backup        = false  # Disable backups in dev
  enable_monitoring    = true
  
  tags = {
    environment = "dev"
    project     = "config-management"
    managed_by  = "terraform"
    owner       = "adrian.johnson@contoso.com"
    cost_center = "IT-Operations"
  }
}

# Outputs
output "resource_group_name" {
  description = "Name of the created resource group"
  value       = module.azure_infrastructure.resource_group_name
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.azure_infrastructure.vnet_id
}

output "vault_cluster_ips" {
  description = "Private IP addresses of Vault cluster nodes"
  value       = module.azure_infrastructure.vault_cluster_ips
}

output "prometheus_ip" {
  description = "Private IP address of Prometheus server"
  value       = module.azure_infrastructure.prometheus_ip
}

output "grafana_ip" {
  description = "Private IP address of Grafana server"
  value       = module.azure_infrastructure.grafana_ip
}

output "key_vault_uri" {
  description = "URI of the Azure Key Vault"
  value       = module.azure_infrastructure.key_vault_uri
  sensitive   = true
}


