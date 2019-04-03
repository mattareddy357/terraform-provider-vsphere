#!/bin/sh
set -e

SWITCH_NAME=vSwitch1

echo "Creating $SWITCH_NAME ..."
esxcfg-vswitch --add $SWITCH_NAME

echo "Finding NIC by MAC address ${nic_mac_addr} ..."
NIC_NAME=$(esxcfg-nics -l | awk '{if($7 == "${nic_mac_addr}"){ print $1 }}')
echo "Found $NIC_NAME."

echo "Adding $NIC_NAME as uplink to $SWITCH_NAME"
esxcfg-vswitch --link=$NIC_NAME $SWITCH_NAME
echo "$NIC_NAME added as uplink to $SWITCH_NAME"

echo "Creating ${length(vlans)} port groups ..."
%{ for idx, vlan in vlans ~}
esxcfg-vswitch --add-pg=${vlan.name} $SWITCH_NAME
esxcfg-vswitch --vlan=${vlan_ids[idx]} --pg=${vlan.name} $SWITCH_NAME
%{ endfor }

echo "ESX network configuration done."
