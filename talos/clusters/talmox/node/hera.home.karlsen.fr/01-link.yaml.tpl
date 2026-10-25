# yaml-language-server: $schema=https://raw.githubusercontent.com/siderolabs/talos/refs/heads/release-1.14/website/content/v1.14/schemas/config.schema.json
# hera's single 2.5GbE port (Intel I226-V), named lan0 by its MAC, which all/02-link.yaml.tpl runs DHCP on and
# control-plane/01-vip.yaml.tpl announces the VIP on (link: lan0 in topf.yaml). No bond: the NUC 15 Pro+ has one
# port. Named by MAC rather than by driver or slot, as on the NUC 16s, so the Wi-Fi card can never be picked up.
# - https://docs.siderolabs.com/talos/v1.14/reference/configuration/network/linkaliasconfig
---
apiVersion: v1alpha1
kind: LinkAliasConfig
name: lan0
selector:
  match: mac(link.permanent_addr) == "{{ .Node.Data.mac0 | lower }}"
