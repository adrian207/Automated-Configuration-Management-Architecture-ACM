# Management, monitoring and data tier VMs beyond Vault, Prometheus and Grafana,
# plus optional managed nodes and backups.
# Author: Adrian Johnson <adrian207@gmail.com>
#
# Static IPs match the Ansible inventory (ansible/inventory/<env>/hosts.yml):
#   management  .20-.22 Vault, .30-.31 DSC pull servers, .40 AWX
#   monitoring  .10 Prometheus, .20 Grafana, .30 Alertmanager
#   data        .10-.11 PostgreSQL

locals {
  ubuntu_image = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Linux service VMs: name => settings
  linux_services = merge(
    var.awx_enabled ? {
      awx = { subnet_id = azurerm_subnet.management.id, ip = cidrhost(var.subnet_management, 40), size = var.vm_size_awx, disk = 128, tier = "management" }
    } : {},
    {
      alertmanager = { subnet_id = azurerm_subnet.monitoring.id, ip = cidrhost(var.subnet_monitoring, 30), size = var.vm_size_alertmanager, disk = 64, tier = "monitoring" }
    },
    { for i in range(var.postgres_node_count) :
      "postgres-${i + 1}" => { subnet_id = azurerm_subnet.data.id, ip = cidrhost(var.subnet_data, 10 + i), size = var.vm_size_data, disk = 256, tier = "data" }
    }
  )

  # Enables WinRM over HTTPS (5986) with a self-signed certificate so Ansible can manage the VM
  winrm_https_script = join("; ", [
    "$c = New-SelfSignedCertificate -DnsName $env:COMPUTERNAME -CertStoreLocation Cert:\\LocalMachine\\My",
    "Get-ChildItem WSMan:\\localhost\\Listener | Where-Object { $_.Keys -contains 'Transport=HTTPS' } | Remove-Item -Recurse -Force",
    "New-Item -Path WSMan:\\localhost\\Listener -Transport HTTPS -Address * -CertificateThumbPrint $c.Thumbprint -Force",
    "New-NetFirewallRule -DisplayName 'WinRM HTTPS' -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow",
  ])

  windows_vms = merge(
    { for i in range(var.dsc_node_count) :
      "dsc-${i + 1}" => { subnet_id = azurerm_subnet.management.id, ip = cidrhost(var.subnet_management, 30 + i), size = var.vm_size_dsc, tier = "management", role = "dsc-pull" }
    },
    { for i in range(var.windows_node_count) :
      "winnode-${i + 1}" => { subnet_id = azurerm_subnet.nodes.id, ip = null, size = var.vm_size_node, tier = "nodes", role = "managed-node" }
    }
  )
}

# ---------------------------------------------------------------------------------------
# Linux service VMs: AWX, Alertmanager, PostgreSQL
# ---------------------------------------------------------------------------------------
resource "azurerm_network_interface" "service" {
  for_each            = local.linux_services
  name                = "nic-${each.key}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = each.value.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.ip
  }
}

resource "azurerm_linux_virtual_machine" "service" {
  for_each                        = local.linux_services
  name                            = "vm-${each.key}-${var.environment}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = each.value.size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.service[each.key].id]
  tags                            = merge(var.tags, { role = each.key, tier = each.value.tier })

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    name                 = "osdisk-${each.key}-${var.environment}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = each.value.disk
  }

  source_image_reference {
    publisher = local.ubuntu_image.publisher
    offer     = local.ubuntu_image.offer
    sku       = local.ubuntu_image.sku
    version   = local.ubuntu_image.version
  }
}

# ---------------------------------------------------------------------------------------
# Windows VMs: DSC pull servers and optional Windows managed nodes
# ---------------------------------------------------------------------------------------
resource "azurerm_network_interface" "windows" {
  for_each            = local.windows_vms
  name                = "nic-${each.key}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = each.value.subnet_id
    private_ip_address_allocation = each.value.ip == null ? "Dynamic" : "Static"
    private_ip_address            = each.value.ip
  }
}

resource "azurerm_windows_virtual_machine" "windows" {
  for_each              = local.windows_vms
  name                  = "vm-${each.key}-${var.environment}"
  computer_name         = substr(replace("${each.key}${var.environment}", "-", ""), 0, 15)
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  size                  = each.value.size
  admin_username        = var.windows_admin_username
  admin_password        = var.windows_admin_password
  network_interface_ids = [azurerm_network_interface.windows[each.key].id]
  tags                  = merge(var.tags, { role = each.value.role, tier = each.value.tier })

  os_disk {
    name                 = "osdisk-${each.key}-${var.environment}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  lifecycle {
    precondition {
      condition     = var.windows_admin_password != null
      error_message = "Set windows_admin_password when dsc_node_count or windows_node_count is above 0."
    }
  }
}

resource "azurerm_virtual_machine_extension" "winrm_https" {
  for_each             = local.windows_vms
  name                 = "enable-winrm-https"
  virtual_machine_id   = azurerm_windows_virtual_machine.windows[each.key].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  tags                 = var.tags

  protected_settings = jsonencode({
    commandToExecute = "powershell -NoProfile -ExecutionPolicy Bypass -Command \"${local.winrm_https_script}\""
  })
}

# ---------------------------------------------------------------------------------------
# Optional RHEL managed nodes
# ---------------------------------------------------------------------------------------
resource "azurerm_network_interface" "linux_node" {
  count               = var.linux_node_count
  name                = "nic-linuxnode-${count.index + 1}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.nodes.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "linux_node" {
  count                           = var.linux_node_count
  name                            = "vm-linuxnode-${count.index + 1}-${var.environment}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = var.vm_size_node
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.linux_node[count.index].id]
  tags                            = merge(var.tags, { role = "managed-node", tier = "nodes" })

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "9-lvm-gen2"
    version   = "latest"
  }
}

# ---------------------------------------------------------------------------------------
# Optional VM backups (enable_backup): Vault and PostgreSQL hold the state worth keeping
# ---------------------------------------------------------------------------------------
resource "azurerm_recovery_services_vault" "main" {
  count               = var.enable_backup ? 1 : 0
  name                = "rsv-${var.environment}-configmgmt"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  soft_delete_enabled = true
  tags                = var.tags
}

resource "azurerm_backup_policy_vm" "daily" {
  count               = var.enable_backup ? 1 : 0
  name                = "daily-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  recovery_vault_name = azurerm_recovery_services_vault.main[0].name

  backup {
    frequency = "Daily"
    time      = "02:00"
  }

  retention_daily {
    count = var.backup_retention_days
  }
}

resource "azurerm_backup_protected_vm" "stateful" {
  for_each = var.enable_backup ? merge(
    { for i, vm in azurerm_linux_virtual_machine.vault : "vault-${i + 1}" => vm.id },
    { for k, vm in azurerm_linux_virtual_machine.service : k => vm.id if startswith(k, "postgres-") }
  ) : {}
  resource_group_name = azurerm_resource_group.main.name
  recovery_vault_name = azurerm_recovery_services_vault.main[0].name
  source_vm_id        = each.value
  backup_policy_id    = azurerm_backup_policy_vm.daily[0].id
}
