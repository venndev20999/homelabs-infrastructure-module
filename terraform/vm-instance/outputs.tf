output "id" {
  description = "Domain ID"
  value       = libvirt_domain.vm.id
}

output "name" {
  description = "Domain name"
  value       = libvirt_domain.vm.name
}

output "mac_address" {
  description = "Assigned MAC address"
  value       = libvirt_domain.vm.network_interface[0].mac
}

output "ip_address" {
  description = "Assigned IP address"
  value       = var.ip_address
}

output "volume_id" {
  description = "Volume ID"
  value       = libvirt_volume.vm_disk.id
}
