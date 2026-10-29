packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.4"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# ── Variables ─────────────────────────────────────────────────────────────────
variable "proxmox_url"      { type = string }
variable "proxmox_username" { type = string }
variable "proxmox_password" {
  type = string
  sensitive = true
  }
variable "proxmox_node"     { type = string }
variable "storage_pool"     { type = string }
variable "win_iso"          { type = string }
variable "virtio_iso"       { type = string }
variable "win_password" {
  type = string 
  sensitive = true
  }
variable "template_id" { 
  type = number
  default = 9010
  }

# ── Source ───────────────────────────────────────────────────────────────────
source "proxmox-iso" "windows" {
  # Подключение к Proxmox
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  password                 = var.proxmox_password
  node                     = var.proxmox_node
  insecure_skip_tls_verify = true

  # VM параметры шаблона
  vm_id   = var.template_id
  vm_name = "windows-template"

  os       = "win11"   # win10 для WinServer 2022/2025, win11 для Windows 11
  cpu_type = "host"
  cores    = 4
  memory   = 4096

  # Диск на VirtIO SCSI
  scsi_controller = "virtio-scsi-single"
  disks {
    disk_size         = "60G"
    storage_pool      = var.storage_pool
    type              = "scsi"
    discard           = true
    io_thread         = true
  }

  # Сеть VirtIO
  network_adapters {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = false
    vlan_tag = 9
  }

  # ── ISO: основной образ Windows ──────────────────────────────────────────
  boot_iso {
    iso_file    = var.win_iso
    unmount     = true
  }

  # ── ISO: autounattend.xml (Packer сам создаёт CD с этими файлами) ────────
  additional_iso_files {
    cd_files = [
      "./packer/http/autounattend.xml",
    ]
    cd_label            = "Unattend"
    unmount             = true
    iso_storage_pool    = "local"
  }

  # ── ISO: VirtIO драйверы ─────────────────────────────────────────────────
  additional_iso_files {
    iso_file = var.virtio_iso
    unmount  = true
  }

  # ── QEMU Guest Agent ─────────────────────────────────────────────────────
  qemu_agent = true

  # ── TPM (обязательно для Windows 11, опционально для WinServer) ──────────
  # Раскомментируй для Windows 11:
   tpm_config {
     tpm_storage_pool = var.storage_pool
     tpm_version = "v2.0"
   }

  # EFI диск (нужен для Secure Boot / Windows 11)
  # Раскомментируй для Windows 11:
   efi_config {
     efi_storage_pool  = var.storage_pool
     efi_type          = "4m"
     pre_enrolled_keys = true
   }

  # ── Communicator: WinRM (вместо SSH как у Linux) ─────────────────────────
  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_password = var.win_password
  winrm_use_ssl  = false
  winrm_insecure = true
  winrm_timeout  = "60m"   # Windows устанавливается дольше Linux

  # Ждём пока WinRM поднимется после перезагрузок
  boot_wait = "5s"
  boot_command = ["<spacebar>"]  # снять скринсейвер если появится

  template_description = "Windows template built by Packer on ${formatdate("YYYY-MM-DD", timestamp())}"
}

# ── Build ─────────────────────────────────────────────────────────────────────
build {
  sources = ["source.proxmox-iso.windows"]

  # 1. Установить VirtIO драйверы (сеть, диск, balloon, qemu-guest-agent)
  provisioner "powershell" {
    script = "./packer/scripts/01-install-virtio.ps1"
  }

  # 2. Установить cloudbase-init (аналог cloud-init — нужен для Terraform initialization)
  provisioner "powershell" {
    script = "./packer/scripts/02-install-cloudbase-init.ps1"
  }

  # 3. Базовые настройки Windows (отключить ненужное, включить нужное)
  provisioner "powershell" {
    script = "./packer/scripts/03-windows-setup.ps1"
  }

  # 4. Sysprep — ВСЕГДА последним, генерализирует образ (VM выключится сама)
  provisioner "powershell" {
    script = "./packer/scripts/04-sysprep.ps1"
  }
}
