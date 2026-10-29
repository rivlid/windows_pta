variable "proxmox_endpoint" { type = string }
variable "proxmox_username" { type = string }
variable "proxmox_password" { type = string sensitive = true }
variable "proxmox_node"     { type = string }

variable "vm_count"    { type = number }
variable "vm_id"       { type = number }
variable "vm_name"     { type = string }
variable "vm_cores"    { type = number }
variable "vm_memory"   { type = number }
variable "vm_disk_size"{ type = number }
variable "vm_tags"     { type = list(string) default = [] }

variable "storage_pool" { type = string }
variable "template_id"  { type = number default = 9010 }

variable "vlan_id"     { type = number default = 0 }
variable "dns_domain"  { type = string default = "" }
variable "dns_servers" { type = list(string) default = ["8.8.8.8", "8.8.4.4"] }
variable "dhcp"        { type = bool default = true }
variable "ip_address"  { type = string default = "0.0.0.0/24" }
variable "ip_gateway"  { type = string default = "" }

variable "win_password" { type = string sensitive = true }
