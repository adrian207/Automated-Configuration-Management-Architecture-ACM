# Plan-time checks for the Azure module with a mocked provider (no Azure credentials needed).
# Run from terraform/modules/azure:  terraform init -backend=false && terraform test

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id = "00000000-0000-0000-0000-000000000000"
      object_id = "00000000-0000-0000-0000-000000000000"
    }
  }
}

variables {
  environment            = "dev"
  location               = "eastus"
  resource_group_name    = "rg-test"
  vnet_address_space     = ["10.10.0.0/16"]
  subnet_management      = "10.10.10.0/24"
  subnet_monitoring      = "10.10.20.0/24"
  subnet_data            = "10.10.30.0/24"
  subnet_nodes           = "10.10.100.0/22"
  admin_username         = "azureuser"
  ssh_public_key_path    = "tests/fixtures/test_ssh_key.pub" # throwaway public key, test only
  windows_admin_password = "Test-Passw0rd!"
  enable_backup          = false
}

run "default_layout_matches_inventory" {
  command = plan

  assert {
    condition     = length(azurerm_linux_virtual_machine.vault) == 3
    error_message = "Expected 3 Vault nodes"
  }
  assert {
    condition     = [for n in azurerm_network_interface.vault : n.ip_configuration[0].private_ip_address] == ["10.10.10.20", "10.10.10.21", "10.10.10.22"]
    error_message = "Vault IPs must match the inventory"
  }
  assert {
    condition     = azurerm_network_interface.service["awx"].ip_configuration[0].private_ip_address == "10.10.10.40"
    error_message = "AWX IP must be 10.10.10.40"
  }
  assert {
    condition     = azurerm_network_interface.service["alertmanager"].ip_configuration[0].private_ip_address == "10.10.20.30"
    error_message = "Alertmanager IP must be 10.10.20.30"
  }
  assert {
    condition     = [azurerm_network_interface.service["postgres-1"].ip_configuration[0].private_ip_address, azurerm_network_interface.service["postgres-2"].ip_configuration[0].private_ip_address] == ["10.10.30.10", "10.10.30.11"]
    error_message = "PostgreSQL IPs must be 10.10.30.10 and .11"
  }
  assert {
    condition     = [azurerm_network_interface.windows["dsc-1"].ip_configuration[0].private_ip_address, azurerm_network_interface.windows["dsc-2"].ip_configuration[0].private_ip_address] == ["10.10.10.30", "10.10.10.31"]
    error_message = "DSC pull server IPs must be 10.10.10.30 and .31"
  }
  assert {
    condition     = length(azurerm_linux_virtual_machine.linux_node) == 0 && length(azurerm_recovery_services_vault.main) == 0
    error_message = "No managed nodes or backup vault by default in this test"
  }
  assert {
    condition     = length(azurerm_virtual_machine_extension.winrm_https) == 2
    error_message = "Both DSC pull servers need the WinRM HTTPS extension"
  }
}

run "backups_and_nodes" {
  command = plan

  variables {
    enable_backup      = true
    linux_node_count   = 2
    windows_node_count = 1
  }

  assert {
    condition     = length(azurerm_recovery_services_vault.main) == 1
    error_message = "enable_backup must create a Recovery Services vault"
  }
  assert {
    condition     = toset(keys(azurerm_backup_protected_vm.stateful)) == toset(["vault-1", "vault-2", "vault-3", "postgres-1", "postgres-2"])
    error_message = "Backups must cover the Vault and PostgreSQL VMs"
  }
  assert {
    condition     = length(azurerm_linux_virtual_machine.linux_node) == 2 && length(azurerm_windows_virtual_machine.windows) == 3
    error_message = "Expected 2 RHEL nodes and 3 Windows VMs (2 DSC + 1 node)"
  }
}

run "windows_password_required" {
  command = plan

  variables {
    windows_admin_password = null
  }

  expect_failures = [azurerm_windows_virtual_machine.windows]
}
