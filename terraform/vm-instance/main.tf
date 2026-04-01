terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = ">= 0.7.6"
    }
  }
}

resource "libvirt_volume" "vm_disk" {
  name             = "${var.name}.qcow2"
  pool             = var.pool
  base_volume_name = var.base_volume_name
  # If disk_size is provided, resize it. Else, use the base volume's size.
  size   = var.disk_size != null ? var.disk_size * 1024 * 1024 * 1024 : null
  format = "qcow2"
}

resource "libvirt_domain" "vm" {
  name   = var.name
  type   = "kvm" # Explicitly define virtualization type
  memory = var.memory
  vcpu   = var.vcpus

  disk {
    volume_id = libvirt_volume.vm_disk.id
  }

  network_interface {
    network_name = var.network_name
    mac          = var.mac_address
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }

  graphics {
    type = "spice"
  }

  video {
    type = "qxl"
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  autostart = true
  running   = true

  lifecycle {
    ignore_changes = [
      # If we don't specify mac, it's generated once and then we keep it.
      network_interface[0].mac
    ]
  }
}

# ── DHCP Reservation logic ──────────────────────────────────────────────
# We use a null_resource to mirror the Ansible logic for DHCP reservation.
# This uses 'virsh net-update' to add/update the reservation.

resource "null_resource" "dhcp_reservation" {
  triggers = {
    name    = var.name
    mac     = libvirt_domain.vm.network_interface[0].mac
    ip      = var.ip_address
    network = var.network_name
  }

  provisioner "local-exec" {
    command = <<EOT
      MAC="${libvirt_domain.vm.network_interface[0].mac}"
      IP="${var.ip_address}"
      NAME="${var.name}"
      NETWORK="${var.network_name}"

      # Try to delete existing assignment for this MAC or IP if it exists
      EXISTING_MAC=$(virsh net-dumpxml "$NETWORK" | grep -i "mac='$MAC'" | sed 's/^\s*//' | head -1)
      if [ -n "$EXISTING_MAC" ]; then
        virsh net-update "$NETWORK" delete ip-dhcp-host --xml "$EXISTING_MAC" --live --config || true
      fi

      EXISTING_IP=$(virsh net-dumpxml "$NETWORK" | grep -i "ip='$IP'" | sed 's/^\s*//' | head -1)
      if [ -n "$EXISTING_IP" ]; then
         if [ "$EXISTING_IP" != "$EXISTING_MAC" ]; then
           virsh net-update "$NETWORK" delete ip-dhcp-host --xml "$EXISTING_IP" --live --config || true
         fi
      fi

      # Add the new reservation
      virsh net-update "$NETWORK" add ip-dhcp-host \
        --xml "<host mac='$MAC' name='$NAME' ip='$IP'/>" \
        --live --config
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      MAC="${self.triggers.mac}"
      IP="${self.triggers.ip}"
      NAME="${self.triggers.name}"
      NETWORK="${self.triggers.network}"

      # Find and delete the host entry
      XML="<host mac='$MAC' name='$NAME' ip='$IP'/>"
      virsh net-update "$NETWORK" delete ip-dhcp-host --xml "$XML" --live --config || true
    EOT
  }

  depends_on = [libvirt_domain.vm]
}
