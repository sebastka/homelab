# Subnet routing comes from the Tailscale operator's Connector on talmox
# (k8s/infrastructure/network/tailscale): its device is created and owned by the operator, and its
# route is approved by policy/autoApprovers.hujson, so nothing per device is managed here.
#
# hermes, the previous subnet router, has been decommissioned and deleted from the tailnet. These
# blocks drop its routes and key settings from state without touching the device; they can go
# once applied.
removed {
  from = tailscale_device_subnet_routes.subnet_router

  lifecycle {
    destroy = false
  }
}

removed {
  from = tailscale_device_key.subnet_router

  lifecycle {
    destroy = false
  }
}
