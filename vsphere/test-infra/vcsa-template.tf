locals {
  vcsa_template = {
    __version = "2.13.0"
    new_vcsa = {
      esxi = {
        hostname           = local.esxi_hosts["esxi-01"].ip_address
        username           = local.esxi_username
        password           = packet_device.esxi.root_password
        deployment_network = "VM Network"
        datastore          = "datastore1"
        ssl_certificate_verification = {
          thumbprint = "_WILL_BE_REPLACED_BY_JQ_"
        }
      }
      appliance = {
        thin_disk_mode    = true
        deployment_option = local.vcenter_deployment_size
        name              = "vcenter-01"
      }
      network = {
        ip_family   = "ipv4"
        mode        = "static"
        dns_servers = [local.vcenter_network["vcenter-01"].vlan.bastion_addr]
        ip          = local.vcenter_network["vcenter-01"].ip_address
        prefix      = split("/", local.vcenter_network["vcenter-01"].vlan.network_cidr)[1]
        gateway     = local.vcenter_network["vcenter-01"].vlan.bastion_addr
        system_name = "${local.vcenter_network["vcenter-01"].ip_address}"
      }
      os = {
        password        = random_string.password.result
        time_tools_sync = true
        ssh_enable      = true
      }
      sso = {
        password       = random_string.password.result
        domain_name    = local.vcsa_domain_name
        first_instance = true
      }
    }
    ceip = {
      settings = {
        ceip_enabled = false
      }
    }
  }
}

resource "local_file" "vcsa" {
  content  = jsonencode(local.vcsa_template)
  filename = "${path.module}/template.json"
}
