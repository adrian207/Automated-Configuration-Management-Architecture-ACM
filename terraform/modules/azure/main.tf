# Azure Infrastructure Module
# Author: Adrian Johnson <adrian207@gmail.com>
# Description: Provisions core Azure infrastructure for configuration management

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.0"
    }
  }
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = merge(var.tags, { environment = var.environment })
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.environment}-configmgmt"
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

# Subnets
resource "azurerm_subnet" "management" {
  name                 = "subnet-management"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_management]
}

resource "azurerm_subnet" "monitoring" {
  name                 = "subnet-monitoring"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_monitoring]
}

resource "azurerm_subnet" "data" {
  name                 = "subnet-data"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_data]
}

resource "azurerm_subnet" "nodes" {
  name                 = "subnet-nodes"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_nodes]
}

# Network Security Groups
resource "azurerm_network_security_group" "management" {
  name                = "nsg-management-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowVault"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8200"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "monitoring" {
  name                = "nsg-monitoring-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  security_rule {
    name                       = "AllowPrometheus"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9090"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowGrafana"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowNodeExporter"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9100"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

# Associate NSGs with Subnets
resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.management.id
}

resource "azurerm_subnet_network_security_group_association" "monitoring" {
  subnet_id                 = azurerm_subnet.monitoring.id
  network_security_group_id = azurerm_network_security_group.monitoring.id
}

# Vault Cluster VMs
resource "azurerm_network_interface" "vault" {
  count               = var.vault_node_count
  name                = "nic-vault-${count.index + 1}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.management.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(var.subnet_management, 20 + count.index)
  }
}

resource "azurerm_linux_virtual_machine" "vault" {
  count                           = var.vault_node_count
  name                            = "vm-vault-${count.index + 1}-${var.environment}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = var.vm_size_vault
  admin_username                  = var.admin_username
  disable_password_authentication = true
  tags                            = merge(var.tags, { role = "vault", tier = "management" })

  network_interface_ids = [
    azurerm_network_interface.vault[count.index].id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    name                 = "osdisk-vault-${count.index + 1}-${var.environment}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init/vault.yaml", {
    node_id     = count.index + 1
    environment = var.environment
  }))
}

# Prometheus Server
resource "azurerm_network_interface" "prometheus" {
  name                = "nic-prometheus-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.monitoring.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(var.subnet_monitoring, 10)
  }
}

resource "azurerm_linux_virtual_machine" "prometheus" {
  name                            = "vm-prometheus-${var.environment}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = var.vm_size_monitoring
  admin_username                  = var.admin_username
  disable_password_authentication = true
  tags                            = merge(var.tags, { role = "prometheus", tier = "monitoring" })

  network_interface_ids = [
    azurerm_network_interface.prometheus.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    name                 = "osdisk-prometheus-${var.environment}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 256
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

# Grafana Server
resource "azurerm_network_interface" "grafana" {
  name                = "nic-grafana-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.monitoring.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(var.subnet_monitoring, 20)
  }
}

resource "azurerm_linux_virtual_machine" "grafana" {
  name                            = "vm-grafana-${var.environment}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = "Standard_D2s_v3"
  admin_username                  = var.admin_username
  disable_password_authentication = true
  tags                            = merge(var.tags, { role = "grafana", tier = "monitoring" })

  network_interface_ids = [
    azurerm_network_interface.grafana.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    name                 = "osdisk-grafana-${var.environment}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

# Azure Key Vault for Secrets
resource "azurerm_key_vault" "main" {
  name                       = "kv-${var.environment}-cfg-${random_string.suffix.result}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium"
  soft_delete_retention_days = 90
  purge_protection_enabled   = true
  tags                       = var.tags

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    virtual_network_subnet_ids = [
      azurerm_subnet.management.id,
      azurerm_subnet.monitoring.id,
      azurerm_subnet.data.id
    ]
  }
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

data "azurerm_client_config" "current" {}


