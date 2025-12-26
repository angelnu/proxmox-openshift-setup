##############################
# Creating Service machine.
##############################
resource "proxmox_vm_qemu" "cloudinit-nodes" {
  name        = local.service.name
  vmid        = local.service.vmid
  target_node = local.service.target_host
  clone       = local.service.os
  full_clone  = true
  boot        = "order=scsi0;net0" # "c" by default, which renders the coreos35 clone non-bootable. "cdn" is HD, DVD and Network
  agent       = 1
  tags        = "okd,service"
  vm_state    = local.service.boot # start once created


  cpu {
    cores  = local.service.cores
    limit   = 0
    numa    = false
    sockets = 1
    type    = "host"
    units   = 0
    vcores  = 0
  }
  memory = local.service.ram
  scsihw = "virtio-scsi-pci"
  #bootdisk = "scsi0"
  hotplug = 0

  disks {
    scsi {
      scsi0 {
        disk {
          storage = "local-lvm"
          size    = "120G"
          format  = "raw"
        }
      }
    }
    ide {
      ide0 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
  }
  network {
    id      = 0
    model   = "virtio"
    bridge  = local.network.bridge
    tag     = local.network.vlan
    macaddr = local.service.macaddr
  }

  # cloud-init config 
  cicustom   = "vendor=local:snippets/centos-qemu-agent.yml" # This installs the Qemu Guest Agent. Install the file in /var/lib/vz/snippets on proxmox host
  ciupgrade  = true
  nameserver = local.network.resolver
  ipconfig0  = "ip=${local.service.ip}/${local.network.lab_subnet},gw=${local.network.lab_gw}"
  skip_ipv6  = true
  ciuser     = var.ansible_user
  cipassword = var.ansible_pwd
  sshkeys    = var.ansible_ssh_public_key

  startup_shutdown {
    order            = -1
    shutdown_timeout = -1
    startup_delay    = -1
  }
}

###################################
# Creating all PXE booting devices.
###################################
resource "proxmox_vm_qemu" "pxe-nodes" {
  for_each    = local.all_pxe_nodes
  name        = "okd-${each.key}"
  vmid        = each.value.vmid
  target_node = each.value.target_host
  # clone       = each.value.os
  disk {
    slot    = "ide2"
    type    = "cdrom"
    iso     = each.value.iso
  }
  full_clone  = true
  boot        = "order=scsi0;net0" # "c" by default, which renders the coreos35 clone non-bootable. "cdn" is HD, DVD and Network
  agent       = 0
  tags        = "okd"
  vm_state    = each.value.boot # start once created

  cpu {
    cores  = each.value.cores
    limit   = 0
    numa    = false
    sockets = 1
    type    = "host"
    units   = 0
    vcores  = 0
  }
  memory = each.value.ram
  scsihw = "virtio-scsi-pci"
  #bootdisk = "scsi0"
  hotplug = 0

  disk {
    slot    = "scsi0"
    size    = "120G"
    type    = "disk"
    storage = "local-lvm"
    format  = "raw"
    #iothread = 1
  }
  network {
    id      = 0
    model   = "virtio"
    bridge  = local.network.bridge
    tag     = local.network.vlan
    macaddr = each.value.macaddr
  }
  startup_shutdown {
    order            = -1
    shutdown_timeout = -1
    startup_delay    = -1
  }
}

resource "local_file" "ansible_inventory" {
  content = templatefile("templates/hosts.tmpl",
    {
      service_ip   = local.service.ip
      bootstrap_ip = local.bootstrap.ip
      masters      = [for j in local.masters : j.ip]
      workers      = [for j in local.workers : j.ip]
    }
  )
  filename = "inventory/hosts.ini"
}
