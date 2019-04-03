#!/bin/bash
set -e

echo "Attempting to login via govc..."
export GOVC_USERNAME="${vcenter_username}"
export GOVC_PASSWORD="${vcenter_password}"
export GOVC_URL=${vcenter_url}
export GOVC_INSECURE=1
./govc about

echo "Creating datacenter..."
./govc datacenter.create ${datacenter_name}

TMP_FILE=$(mktemp)
echo "${private_key_pem}" > $TMP_FILE
echo "private key stored temporarily at "$TMP_FILE

echo "Sourcing SSL certificate thumbprint for ESXi (${esxi_hostname}) ..."
CMD="openssl x509 -in /etc/vmware/ssl/rui.crt -fingerprint -sha1 -noout"
SSL_CERT_THUMBPRINT=$(ssh -o StrictHostKeyChecking=no -i $TMP_FILE ${esxi_username}@${esxi_hostname} "$CMD" | awk -F= '{print $2}')
echo "Sourced SSL certificate thumbprint: "$SSL_CERT_THUMBPRINT

rm -f $TMP_FILE
echo "private key removed from "$TMP_FILE

echo "Adding ESXi as host to the datacenter..."
./govc host.add -hostname ${esxi_hostname} -username ${esxi_username} -password '${esxi_password}' -thumbprint $SSL_CERT_THUMBPRINT
