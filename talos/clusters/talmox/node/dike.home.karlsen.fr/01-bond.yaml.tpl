# Both 2.5GbE ports bonded into bond0, which all/02-link.yaml.tpl runs DHCP on and
# control-plane/01-vip.yaml.tpl announces the VIP on (link: bond0 in topf.yaml).
# - https://docs.siderolabs.com/talos/v1.14/reference/configuration/network/bondconfig
# - https://docs.siderolabs.com/talos/v1.14/reference/configuration/network/linkaliasconfig
#
# harmonia only does static link aggregation, not LACP, hence balance-xor rather than 802.3ad.
# Hashing on IP and port spreads flows over both links; any single flow stays at 2.5G.
#
# The members are named by MAC rather than by driver, so the Wi-Fi card can never be picked up.
# The bond's MAC is pinned to mac0: it would otherwise be whichever member the kernel enslaves
# first, and the Kea reservation on helios has to be keyed on a known MAC.
---
apiVersion: v1alpha1
kind: LinkAliasConfig
name: lan0
selector:
  match: mac(link.permanent_addr) == "{{ .Node.Data.mac0 | lower }}"
---
apiVersion: v1alpha1
kind: LinkAliasConfig
name: lan1
selector:
  match: mac(link.permanent_addr) == "{{ .Node.Data.mac1 | lower }}"
---
apiVersion: v1alpha1
kind: BondConfig
name: bond0
links: [lan0, lan1]
hardwareAddr: {{ .Node.Data.mac0 | lower }}
bondMode: balance-xor
xmitHashPolicy: layer3+4
miimon: 100
