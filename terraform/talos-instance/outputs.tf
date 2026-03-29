output "id" {
  description = "Domain ID"
  value       = libvirt_domain.talos.id
}

output "name" {
  description = "Domain name"
  value       = libvirt_domain.talos.name
}

output "mac_address" {
  description = "Assigned MAC address"
  value       = libvirt_domain.talos.network_interface[0].mac
}

output "ip_address" {
  description = "Assigned IP address"
  value       = var.ip_address
}
