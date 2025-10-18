# Development Environment Variables
# Author: Adrian Johnson <adrian207@gmail.com>

variable "location" {
  description = "Azure region for dev environment"
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


