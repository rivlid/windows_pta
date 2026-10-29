terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.70"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  username = var.proxmox_username
  password = var.proxmox_password
  insecure = true
}

locals {
  ip_parts    = split("/", var.ip_address)
  ip_octets   = split(".", local.ip_parts[0])
  ip_prefix   = local.ip_parts[1]
  ip_network  = "${local.ip_octets[0]}.${local.ip_octets[1]}.${local.ip_octets[2]}.0/${local.ip_prefix}"
  ip_host_num = tonumber(local.ip_octets[3])
}

resource "proxmox_virtual_environment_vm" "windows" {
  count     = var.vm_count
  vm_id     = var.vm_id + count.index
  name      = "${var.vm_name}-${format("%02d", count.index + 1)}"
  node_name = var.proxmox_node
  tags      = var.vm_tags

  lifecycle {
    ignore_changes = [initialization]
  }

  # Клонировать из шаблона, созданного Packer'ом
  clone {
    vm_id = var.template_id
    full  = true
  }

  cpu {
    cores = var.vm_cores
    type  = "host"  # для Windows лучше host, а не x86-64-v2-AES
  }

  memory {
    dedicated = var.vm_memory
  }

  disk {
    datastore_id = var.storage_pool
    size         = var.vm_disk_size
    interface    = "scsi0"
    discard      = "on"
    iothread     = true
    cache        = "writeback"
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = var.vlan_id
  }

  # QEMU Guest Agent (установлен через VirtIO ISO)
  agent {
    enabled = true
    timeout = "15m"  # Windows стартует дольше Linux
  }

  # TPM — обязательно для Windows 11, опционально для WinServer
  # Раскомментируй для Windows 11:
  tpm_state {
    datastore_id = var.storage_pool
    version      = "v2.0"
  }

  # cloud-init через cloudbase-init
  # Эти параметры передаются через config-drive, cloudbase-init их применяет при старте
  initialization {
    datastore_id = var.storage_pool

    dns {
      servers = var.dns_servers
      domain  = var.dns_domain
    }

    ip_config {
      ipv4 {
        address = var.dhcp ? "dhcp" : "${cidrhost(local.ip_network, local.ip_host_num + count.index)}/${local.ip_prefix}"
        gateway = var.dhcp ? null : var.ip_gateway
      }
    }

    # cloudbase-init устанавливает этот пароль для Administrator
    user_account {
      username = "Administrator"
      password = var.win_password
    }
  }
}

output "vm_ips" {
  value = [for vm in proxmox_virtual_environment_vm.windows : {
    name = vm.name
    id   = vm.vm_id
    ip   = var.dhcp ? try(flatten(vm.ipv4_addresses)[1], "pending") : "${cidrhost(local.ip_network, local.ip_host_num + (vm.vm_id - var.vm_id))}/${local.ip_prefix}"
  }]
}

output "ansible_inventory_hint" {
  description = "Paste into ansible/inventory/hosts.yml"
  value = join("\n", [for vm in proxmox_virtual_environment_vm.windows :
    "    ${vm.name}:\n      ansible_host: ${var.dhcp ? try(flatten(vm.ipv4_addresses)[1], "pending") : cidrhost(local.ip_network, local.ip_host_num + (vm.vm_id - var.vm_id))}"
  ])
}
