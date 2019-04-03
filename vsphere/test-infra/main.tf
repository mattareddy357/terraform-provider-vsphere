terraform {
  required_version = ">= 0.12"
}

provider "packet" {
  version = "~> 2.2"
}

resource "packet_project" "test" {
  name = "Terraform Acc Test vSphere"
}

resource "random_string" "password" {
  length           = 16
  special          = true
  min_lower        = 1
  min_numeric      = 1
  min_upper        = 1
  min_special      = 1
  override_special = "@_"
}

resource "tls_private_key" "test" {
  algorithm = "RSA"
}

resource "packet_project_ssh_key" "test" {
  name       = "tf-acc-test"
  public_key = tls_private_key.test.public_key_openssh
  project_id = packet_project.test.id
}

data "packet_operating_system" "bastion" {
  name   = "Ubuntu"
  distro = "ubuntu"

  # 18.04 has a broken ifupdown version which makes it difficult to setup VLANs
  # See https://bugs.launchpad.net/ubuntu/+source/ifupdown/+bug/1806153
  # 19.04 seems to have a later (fixed) version,
  # but the next LTS is 20.04 (not released yet; planned for Apr 2020)
  version          = "16.04"
  provisionable_on = local.bastion_plan
}

resource "packet_device" "bastion" {
  hostname                = "bastion"
  plan                    = local.bastion_plan
  facilities              = [var.facility]
  operating_system        = data.packet_operating_system.bastion.id
  billing_cycle           = "hourly"
  project_id              = packet_project.test.id
  project_ssh_key_ids     = [packet_project_ssh_key.test.id]
  network_type            = "hybrid"
  public_ipv4_subnet_size = local.bastion_subnet_size
}

# We do the provisioning in a separate step
# as it requires VLANs to be attached
# (which provides connectivity to the ESXi host)
# and public IP range assigned (for VLAN setup)
resource "null_resource" "provisioning" {
  triggers = {
    esxi_id = packet_device.esxi.id
    bastion_id = packet_device.bastion.id
  }

  depends_on = [
    packet_port_vlan_attachment.esxi,
    packet_port_vlan_attachment.bastion
  ]

  connection {
    type        = "ssh"
    host        = packet_device.bastion.access_public_ipv4
    user        = "root"
    private_key = tls_private_key.test.private_key_pem
    agent       = false
  }

  provisioner "remote-exec" {
    inline = [templatefile("${path.module}/scripts/setup-vlan.sh", {
      vlans        = local.vlans,
      vlan_ids     = packet_vlan.default.*.vxlan
      nic_mac_addr = [for port in packet_device.bastion.ports : port if port.name == "eth1"][0].mac,
    })]
  }

  provisioner "remote-exec" {
    inline = [templatefile("${path.module}/scripts/configure-nat.sh", {
      natted_vlans = [for vlan in local.vlans : vlan if vlan.nat == true]
    })]
  }

  provisioner "remote-exec" {
    inline = [templatefile("${path.module}/scripts/iptables.sh", {
      block_dns_vlans = [for vlan in local.vlans : vlan if vlan.dns == false]
    })]
  }

  provisioner "remote-exec" {
    inline = [templatefile("${path.module}/scripts/install-and-configure-dnsmasq.sh", {
      listen_addresses = concat(["127.0.0.1"], local.vlans.*.bastion_addr)
      dns_servers      = var.dns_servers
      vlans            = local.vlans
      domain_name      = local.vcsa_domain_name
      esxi_hosts       = local.esxi_hosts
      vcenter_network  = local.vcenter_network
    })]
  }

  provisioner "file" {
    source      = local_file.vcsa.filename
    destination = "/tmp/vcsa-template.json"
  }

  provisioner "remote-exec" {
    inline = [templatefile("${path.module}/scripts/install-vcsa.sh", {
      ovftool_url     = var.ovftool_url
      vcsa_iso_url    = var.vcsa_iso_url
      private_key_pem = tls_private_key.test.private_key_pem
      vcsa_tpl_path   = "/tmp/vcsa-template.json"
    })]
  }

  provisioner "remote-exec" {
    inline = [templatefile("${path.module}/scripts/install-govc.sh", {
      govc_url = local.govc_url
    })]
  }

  provisioner "remote-exec" {
    inline = [templatefile("${path.module}/scripts/add-esxi-host-to-vcenter.sh", {
      vcenter_username = local.vcenter_username
      vcenter_password = random_string.password.result
      vcenter_url      = local.vcenter_network["vcenter-01"].ip_address
      datacenter_name  = local.datacenter_name
      esxi_hostname    = local.esxi_hosts["esxi-01"].ip_address
      esxi_username    = local.esxi_username
      esxi_password    = packet_device.esxi.root_password
      private_key_pem  = tls_private_key.test.private_key_pem
    })]
  }

  provisioner "remote-exec" {
    connection {
      type    = "ssh"
      timeout = "10m"

      host        = local.esxi_hosts["esxi-01"].ip_address
      user        = "root"
      private_key = tls_private_key.test.private_key_pem
      agent       = false

      bastion_host        = packet_device.bastion.access_public_ipv4
      bastion_user        = "root"
      bastion_private_key = tls_private_key.test.private_key_pem
    }

    inline = [templatefile("${path.module}/scripts/configure-esx-network.sh", {
      vlans        = local.vlans,
      vlan_ids     = packet_vlan.default.*.vxlan
      nic_mac_addr = [for port in packet_device.esxi.ports : port if port.name == "eth1"][0].mac,
    })]
  }
}

data "packet_operating_system" "esxi" {
  name             = "VMware ESXi"
  distro           = "vmware"
  version          = var.esxi_version
  provisionable_on = var.plan
}

resource "packet_device" "esxi" {
  hostname            = "esxi-01"
  plan                = var.plan
  facilities          = [var.facility]
  operating_system    = data.packet_operating_system.esxi.id
  billing_cycle       = "hourly"
  project_id          = packet_project.test.id
  project_ssh_key_ids = [packet_project_ssh_key.test.id]
  network_type        = "layer2-individual"
}

