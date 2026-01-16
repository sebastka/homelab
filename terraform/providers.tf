# https://github.com/Telmate/terraform-provider-proxmox/blob/master/docs/index.md
# https://registry.terraform.io/providers/Telmate/proxmox/latest/docs/guides/cloud_init

terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc07"
    }
  }
}

provider "proxmox" {
  pm_api_url = "https://${var.pve_host}:8006/api2/json"
  # pm_minimum_permission_check = false
  # pm_debug                  = true
}
