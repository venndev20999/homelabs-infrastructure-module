variable "name" {
  description = "Name of the Talos instance"
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

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 30
}

variable "disk_dir" {
  description = "Directory where the disk images will be stored"
  type        = string
  default     = "/var/lib/libvirt/images"
}

variable "iso_path" {
  description = "Path to the Talos ISO file"
  type        = string
  default     = "/var/iso/metal-amd64.iso"
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
