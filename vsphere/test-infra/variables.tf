variable "plan" {
  default = "c1.xlarge.x86"
}

variable "esxi_version" {
  default = "6.5"
}

variable "govc_version" {
  default     = "v0.20.0"
  description = "Version of govc (see https://github.com/vmware/govmomi/releases)"
}

variable "facility" {
  default = "ams1"
}

variable "dns_servers" {
  type    = list(string)
  default = ["1.1.1.1", "8.8.8.8", "8.8.4.4"]
}

variable "ntp_servers" {
  type    = list(string)
  default = ["time.nist.gov"] # TODO: Not actually used anywhere (yet) - set in bastion
}

variable "ovftool_url" {
  description = "URL from which to download ovftool"
}

variable "vcsa_iso_url" {
  description = "URL from which to download VCSA ISO"
}

locals {
  esxi_username           = "root"
  vcsa_domain_name        = "vsphere.local"
  vcenter_username        = "Administrator@${local.vcsa_domain_name}"
  govc_url                = "https://github.com/vmware/govmomi/releases/download/${var.govc_version}/govc_linux_amd64.gz"
  ubuntu_iso_url          = "http://no.releases.ubuntu.com/18.04.2/ubuntu-18.04.2-live-server-amd64.iso"
  bastion_plan            = "m1.xlarge.x86"
  vcenter_system_name     = "vcenter-01"
  vcenter_deployment_size = "small"

  bastion_subnet_size = 29
  bastion_dhcp_from = cidrhost(
    format(
      "%s/%s",
      packet_device.bastion.network[0].gateway,
      packet_device.bastion.public_ipv4_subnet_size,
    ),
    2,
  )
  bastion_dhcp_to = cidrhost(
    format(
      "%s/%s",
      packet_device.bastion.network[0].gateway,
      packet_device.bastion.public_ipv4_subnet_size,
    ),
    6, # Assuming /29
  )

  # ESXi host IPs are assigned via DHCP & MAC address
  # as it's easier in Packet with L2-only setup
  esxi_hosts = {
    esxi-01 = {
      ip_address  = "172.16.1.1"
      mac_address = [for port in packet_device.esxi.ports : port if port.name == "eth0"][0].mac
      vlan        = [for vlan in local.vlans : vlan if vlan.name == "mgmt"][0]
    }
  }

  # vcenter deployment doesn't seem to support customization
  # of NIC MAC address, hence we can't leverage DHCP like we do for ESXi
  # Static configuration is therefore used instead
  vcenter_network = {
    vcenter-01 = {
      ip_address = "172.16.2.1"
      vlan       = [for vlan in local.vlans : vlan if vlan.name == "mgmt"][0]
    }
  }

  vlans = [
    {
      name         = "mgmt"
      bastion_addr = "172.16.0.1"
      network_cidr = "172.16.0.0/22"
      dhcp_range = {
        from       = "172.16.0.100"
        to         = "172.16.0.200"
        lease_time = "12h"
      }
      esxi_port = "eth0"
      dns       = true
      nat       = true
    },
    {
      name         = "private"
      bastion_addr = "172.16.4.1"
      network_cidr = "172.16.4.0/24"
      dhcp_range = {
        from       = "172.16.4.2"
        to         = "172.16.4.250"
        lease_time = "12h"
      }
      esxi_port = "eth1"
      dns       = false
      nat       = false
    },
    {
      name         = "public-via-nat"
      bastion_addr = "172.16.5.1"
      network_cidr = "172.16.5.0/24"
      dhcp_range = {
        from       = "172.16.5.2"
        to         = "172.16.5.250"
        lease_time = "12h"
      }
      esxi_port = "eth1"
      dns       = true
      nat       = true
    },
    {
      name         = "public-routable"
      bastion_addr = packet_device.bastion.access_public_ipv4
      network_cidr = "${packet_device.bastion.network[0].gateway}/${local.bastion_subnet_size}"
      dhcp_range = {
        from       = local.bastion_dhcp_from
        to         = local.bastion_dhcp_to
        lease_time = "24h"
      }
      esxi_port = "eth1"
      dns = true
      nat = true
    },
  ]
  datacenter_name = "TfDatacenter"
}

