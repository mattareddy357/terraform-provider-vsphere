#!/bin/bash
set -e

echo "Installing govc..."
curl -f -L '${govc_url}' -o /tmp/govc_linux_amd64.gz
gunzip /tmp/govc_linux_amd64.gz
mv /tmp/govc_linux_amd64 ./govc
chmod a+x ./govc

./govc version
