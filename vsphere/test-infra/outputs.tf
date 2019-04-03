output "esxi_host" {
  value = local.esxi_hosts["esxi-01"].ip_address
}

output "esxi_user" {
  value = local.esxi_username
}

output "esxi_password" {
  value = packet_device.esxi.root_password
}

output "vcenter_endpoint" {
  value = local.vcenter_network["vcenter-01"].ip_address
}

output "vcenter_user" {
  value = local.vcenter_username
}

output "vcenter_password" {
  value = random_string.password.result
}

output "datacenter_name" {
  value = local.datacenter_name
}

output "bastion_host" {
  value = packet_device.bastion.access_public_ipv4
}

