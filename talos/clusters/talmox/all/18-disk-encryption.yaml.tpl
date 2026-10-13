# yaml-language-server: $schema=https://raw.githubusercontent.com/siderolabs/talos/refs/heads/release-1.14/website/content/v1.14/schemas/config.schema.json
# https://docs.siderolabs.com/talos/v1.14/platform-specific-installations/bare-metal-platforms/secureboot#booting-talos-linux-in-secureboot-mode
#
# allowDiscards lets TRIM reach the zvol underneath, which is what makes the default weekly
# FilesystemTrimConfig do anything on an encrypted volume: without it the LUKS layer swallows
# every discard and freed blocks are never returned to the ZFS pool. The trade-off is that an
# attacker holding the raw disk can see which sectors are in use. EPHEMERAL churns (images,
# logs) and is worth it; STATE is ~88 MB and near-static, so it is left alone.
#
# It takes effect when LUKS next opens the volume, so it applies from the next reboot of each
# node onwards. See also all/13-longhorn.yaml.tpl.
#
# The key comes from nodes[].data.diskKey in topf.yaml:
#   nodeID            derived from the machine UUID. Only stops a casual read of a pulled disk;
#                     all the VMs can offer without a vTPM.
#   tpm               sealed in the TPM against the Secure Boot state, so the volume only opens
#                     on that machine running a Talos image signed with the enrolled key. Used on
#                     the bare-metal NUCs. Refuses to enroll if Secure Boot is off.
# It is chosen here rather than overridden per node because patches append to `keys`, which
# would leave two keys in slot 0. The volume is formatted with the key it is first given:
# changing it later means wiping the volume.
{{- $key := "" }}{{ if eq .Node.Data.diskKey "tpm" }}{{ $key = "tpm: {checkSecurebootStatusOnEnroll: true}" }}{{ else if eq .Node.Data.diskKey "nodeID" }}{{ $key = "nodeID: {}" }}{{ else }}{{ fail (printf "diskKey must be nodeID or tpm, got %q" .Node.Data.diskKey) }}{{ end }}
---
apiVersion: v1alpha1
kind: VolumeConfig
name: STATE
encryption:
  provider: luks2
  keys: [{ {{- $key }}, slot: 0}]
---
apiVersion: v1alpha1
kind: VolumeConfig
name: EPHEMERAL
encryption:
  provider: luks2
  allowDiscards: true
  keys: [{ {{- $key }}, slot: 0}]
