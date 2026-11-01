# Production Environment Variables
# Author: Adrian Johnson <adrian207@gmail.com>

variable "location" {
  description = "Azure region for the production environment"
  type        = string
  default     = "eastus"
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



variable "windows_admin_password" {
  description = "Local administrator password for the Windows VMs (DSC pull servers, Windows nodes)"
  type        = string
  sensitive   = true
}
