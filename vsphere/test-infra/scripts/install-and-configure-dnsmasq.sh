#!/bin/bash
set -e

echo "Installing dnsmasq ..."
apt-get -y install dnsmasq

echo "Configuring dnsmasq ..."
cat <<EOT > /etc/dnsmasq.d/default.conf
listen-address=${join(",", listen_addresses)}

no-resolv
dnssec
%{ for server in dns_servers ~}
server=${server}#53
%{ endfor ~}

%{ for name, host in esxi_hosts ~}
dhcp-host=${host.mac_address},set:${host.vlan.name},${host.ip_address},${name}
%{ endfor ~}

%{ for vlan in vlans ~}
dhcp-range=set:${vlan.name},${vlan.dhcp_range.from},${vlan.dhcp_range.to},${cidrnetmask(vlan.network_cidr)},${vlan.dhcp_range.lease_time}
dhcp-option=tag:${vlan.name},option:router,${vlan.bastion_addr}
dhcp-option=tag:${vlan.name},option:ntp-server,0.0.0.0
domain=${vlan.name}.${domain_name},${vlan.network_cidr}
%{ if vlan.dns ~}
dhcp-option=tag:${vlan.name},option:dns-server,${vlan.bastion_addr}
%{ endif ~}
%{ endfor }

log-dhcp
log-queries
EOT

echo "Starting dnsmasq ..."
systemctl start dnsmasq
systemctl restart dnsmasq

echo "dnsmasq configured & started."

echo "Setting dnsmasq as default DNS server ..."
echo "127.0.0.1" > /etc/resolv.conf
echo "Done."
