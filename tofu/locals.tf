locals {
  talos_image = "local:iso/nocloud-amd64-secureboot.iso"

  talos_nodes_hera = {
    "t01" = { cluster = "talmox", vm_id = 151, tags = ["controlplane", "worker"], cpu = 12, mem = 24576, osdisk_size = 64, datadisk_size = 192, hwaddr = "bc:24:11:10:fe:09", ip = "192.168.1.201", gpu = null, image = local.talos_image }
    "t02" = { cluster = "talmox", vm_id = 152, tags = ["controlplane", "worker"], cpu = 12, mem = 24576, osdisk_size = 64, datadisk_size = 192, hwaddr = "bc:24:11:10:fe:0a", ip = "192.168.1.202", gpu = null, image = local.talos_image }
    "t03" = { cluster = "talmox", vm_id = 153, tags = ["controlplane", "worker"], cpu = 12, mem = 24576, osdisk_size = 64, datadisk_size = 192, hwaddr = "bc:24:11:10:fe:0b", ip = "192.168.1.203", gpu = { device = "hostpci0", mapping = "iGPU", pcie = true, rombar = true }, image = local.talos_image }
  }

  vms_hera = {
    "file01" = { role = "storage", vm_id = 107, tags = ["nfs"], machine = "q35", bios = "ovmf", cpu = { cores = 4, sockets = 1, type = "host", numa = true }, mem = 8192, on_boot = true, network = { hwaddr = "BC:24:11:82:E0:A3", ip = "192.168.1.20", fw = 0 }, vga = null, osdisk = { size = 32, ssd = true }, efi_disk = { pre_enrolled_keys = false }, tpm = { version = "v2.0" }, startup = { down_delay = 300 } }
  }

  containers_hera = {
    "db01" = { role = "database", setup_user = false, vm_id = 102, description = "Database server (MariaDB)", tags = ["mariadb"], cores = 4, mem = 4096, hwaddr = "BC:24:11:36:0C:75", ip = "192.168.1.11", rootfs_size = 128 }
    "db02" = { role = "database", setup_user = false, vm_id = 103, description = "Database server (PostgreSQL)", tags = ["postgresql"], cores = 4, mem = 4096, hwaddr = "BC:24:11:F5:DB:10", ip = "192.168.1.12", rootfs_size = 8, mountpoint = { path = "/var/lib/postgresql", size = "128G" } }
  }

}
