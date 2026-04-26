# https://github.com/Telmate/terraform-provider-proxmox/blob/master/docs/index.md
# https://registry.terraform.io/providers/Telmate/proxmox/latest/docs/guides/cloud_init

terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc07"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5"
    }

    # kubernetes = {
    #   source  = "hashicorp/kubernetes"
    #   version = "~> 3"
    # }

    # talos = {
    #   source  = "siderolabs/talos"
    #   version = "~> 0"
    # }
  }
}

provider "proxmox" {
  pm_api_url = "${var.pve.endpoint}/api2/json"
  # pm_minimum_permission_check = false
  # pm_debug                  = true
}

provider "cloudflare" {
  # CLOUDFLARE_API_TOKEN
  # api_token =
}

# provider "kubernetes" {
#   host                   = module.talos.kube_config.kubernetes_client_configuration.host
#   client_certificate     = base64decode(module.talos.kube_config.kubernetes_client_configuration.client_certificate)
#   client_key             = base64decode(module.talos.kube_config.kubernetes_client_configuration.client_key)
#   cluster_ca_certificate = base64decode(module.talos.kube_config.kubernetes_client_configuration.ca_certificate)
# }
