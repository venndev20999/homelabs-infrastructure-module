terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7.6"
    }
  }
}

resource "libvirt_volume" "talos_disk" {
  name = "${var.name}.qcow2"
  # Assuming the 'default' pool is what corresponds to var.disk_dir (/var/lib/libvirt/images)
  pool   = "default"
  size   = var.disk_size * 1024 * 1024 * 1024 # Convert GB to bytes
  format = "qcow2"
}

resource "libvirt_domain" "talos" {
  name   = var.name
  memory = var.memory
  vcpu   = var.vcpus

  disk {
    volume_id = libvirt_volume.talos_disk.id
    # We set scsi here as it is common for libvirt/kvm performance
    # but the Ansible command didn't specify, using default is safer.
  }

  disk {
    file = var.iso_path
  }

  boot_device {
    dev = ["hd", "cdrom", "network"]
  }

  network_interface {
    network_name = var.network_name
    mac          = var.mac_address # Use provided MAC if available
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
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

  # Ensure the VM is created and has a MAC address before we try to update DHCP
  lifecycle {
    ignore_changes = [
      # If we don't specify mac, libvirt will assign it; we don't want to re-create on every plan
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
    mac     = libvirt_domain.talos.network_interface[0].mac
    ip      = var.ip_address
    network = var.network_name
  }

  provisioner "local-exec" {
    command = <<EOT
      MAC="${libvirt_domain.talos.network_interface[0].mac}"
      IP="${var.ip_address}"
      NAME="${var.name}"
      NETWORK="${var.network_name}"

      # Try to delete existing assignment for this MAC or IP if it exists
      # We check for both to avoid conflicts
      EXISTING_MAC=$(virsh net-dumpxml "$NETWORK" | grep "mac='$MAC'" | sed 's/^\s*//' | head -1)
      if [ -n "$EXISTING_MAC" ]; then
        virsh net-update "$NETWORK" delete ip-dhcp-host --xml "$EXISTING_MAC" --live --config || true
      fi

      EXISTING_IP=$(virsh net-dumpxml "$NETWORK" | grep "ip='$IP'" | sed 's/^\s*//' | head -1)
      if [ -n "$EXISTING_IP" ]; then
         # Only delete if it's not the same MAC we just checked (to avoid double delete error)
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

  # When the resource is destroyed, we should ideally clean up the DHCP reservation
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

  depends_on = [libvirt_domain.talos]
}
