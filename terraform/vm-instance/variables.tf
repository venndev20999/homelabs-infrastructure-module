variable "name" {
  description = "Name of the VM instance"
  type        = string
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 2048
}

variable "vcpus" {
  description = "Number of vCPUs"
  type        = number
  default     = 2
}

variable "base_volume_name" {
  description = "Name of the base volume to clone from (e.g., base-server-ubuntu-24.qcow2)"
  type        = string
  default     = "base-server-ubuntu-24.qcow2"
}

variable "pool" {
  description = "The libvirt pool to use"
  type        = string
  default     = "default"
}

variable "network_name" {
  description = "The libvirt network name"
  type        = string
  default     = "default"
}

variable "ip_address" {
  description = "Static IP address for DHCP reservation"
  type        = string
}

variable "mac_address" {
  description = "Optional MAC address to use. If not provided, one will be generated."
  type        = string
  default     = null
}

variable "disk_size" {
  description = "Optional disk size in GB. If specified, the disk will be resized after cloning."
  type        = number
  default     = null
}
