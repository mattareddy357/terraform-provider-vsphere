# Testing Infrastructure

Here is where we keep the code of testing infrastructure (i.e. real vSphere cluster to run tests against).
This is intended to run on a TeamCity agent in AWS.

## Prerequisites

- Obtain API token for Packet.net and put it in the [relevant ENV variable](https://www.terraform.io/docs/providers/packet/#auth_token)
- Register and/or login to the [VMware portal](https://my.vmware.com/web/vmware/login)
- Download [VMware OVF Tool for Linux 64-bit](https://my.vmware.com/group/vmware/details?downloadGroup=OVFTOOL410&productId=353)
- Download [VMware vCenter Server Appliance](https://my.vmware.com/group/vmware/details?downloadGroup=VC67U1B&productId=742&rPId=31320)
- Upload both to an automation-friendly location (such as [S3](https://aws.amazon.com/s3/) or [Wasabi](https://wasabi.com/))
  - Make sure the location of the data is close to the chosen Packet.net facility
  	(the VCSA ISO has around *4GB*, so downloading would take a long time with a slow connection), e.g.
    - Wasabi's `eu-central-1`/Amsterdam & Packet's `ams1`/Amsterdam
    - AWS S3 `eu-central-1`/Frankfurt & Packet's `fra2`/Frankfurt
- Create curl-able URLs - see examples below

## How

### Terraform Apply

```sh
export TF_VAR_ovftool_url=$(aws --profile=vmware s3 presign --expires-in=7200 s3://hc-vmware-eu-central-1/vmware-ovftool/VMware-ovftool-4.3.0-7948156-lin.x86_64.bundle)
export TF_VAR_vcsa_iso_url=$(aws --profile=vmware s3 presign --expires-in=7200 s3://hc-vmware-eu-central-1/vmware-vsphere/VMware-VCSA-all-6.7.0-11726888.iso)
terraform apply -var=facility=ams1 -var=plan=c1.xlarge.x86
```

### TODO

- firewall off both ESXi & helper box
- VLAN with PXE boot
- VLAN for SAN/storage + vSAN
- Use ovftool to create VM from CoreOS OVA https://coreos.com/os/docs/latest/booting-on-vmware.html
- Use ovftool to create VM from Windows OVA https://developer.microsoft.com/en-us/windows/downloads/virtual-machines
- VLAN with publicly routable IPs
- SSL cert via LetsEncrypt?
- Scalability
  - capacity/performance of the cluster (horizontal / vertical scaling)
  - no of users (VPN / ESXi / vCenter)

TODO: VLAN with publicly routable IPs from bastion, so that we don't need to tunnel through to ESXi


SSH tunnel to access ESXi/vCenter web iface when it's fully in L2 network mode:

```sh
ssh -i ~/.ssh/packet-test -nNT  -L 9443:172.16.2.1:443 -L 8443:172.16.1.1:443 root@147.75.82.170
```

SSH to ESXi

```sh
ssh root@172.16.1.1 -o "ProxyCommand ssh -W %h:%p -i ~/.ssh/packet-test root@147.75.82.170"
```

Copy SSH key

```sh
echo 'tls_private_key.test.private_key_pem' | terraform console > ~/.ssh/packet-test
```

### How To

#### Upload ISO to a datastore

From bastion host, or anywhere else:

```sh
ssh root@bastion
wget http://www.mirrorservice.org/sites/releases.ubuntu.com/18.04.2/ubuntu-18.04.2-live-server-amd64.iso
./govc datastore.upload -u='root:${packet_device.esxi.root_password}@${packet_device.esxi.access_public_ipv4}' -ds datastore1 -k=true ./ubuntu-18.04.2-live-server-amd64.iso ./ubuntu-18.04.2-live-server-amd64.iso
# TODO: create & launch VM
```

(faster) straight on ESXi host:

```sh
ssh root@esxi
cd /vmfs/volumes/datastore1
wget http://www.mirrorservice.org/sites/releases.ubuntu.com/18.04.2/ubuntu-18.04.2-live-server-amd64.iso

```

### Deploying OVA

```sh
ssh root@helper
wget "... ova"
ovftool --acceptAllEulas -ds=datastore1 --network=public -n=acisim ./acisim-4.0-3d.ova vi://<VCENTER_IP>/TfDatacenter/host/<ESXI_IP>
```

#### Done on Lab

```sh
VSPHERE_DC_FOLDER=$(govc datacenter.info -json Datacenter | jq -r .Datacenters[0].Parent.Value)
VSPHERE_LICENSE

# Storage
VSPHERE_ADAPTER_TYPE
VSPHERE_DATASTORE
VSPHERE_DATASTORE2
VSPHERE_DS_VMFS_DISK0
VSPHERE_DS_VMFS_DISK1
VSPHERE_DS_VMFS_DISK2
VSPHERE_FOLDER_V0_PATH
VSPHERE_NAS_HOST
VSPHERE_NFS_PATH
VSPHERE_NFS_PATH2
VSPHERE_VMFS_EXPECTED
VSPHERE_VMFS_REGEXP

# Network
VSPHERE_HOST_NIC0
VSPHERE_HOST_NIC1
VSPHERE_IPV4_ADDRESS
VSPHERE_IPV4_GATEWAY
VSPHERE_IPV4_PREFIX
VSPHERE_NETWORK_LABEL
VSPHERE_NETWORK_LABEL_DHCP
VSPHERE_NETWORK_LABEL_PXE

# Other
VSPHERE_ISO_DATASTORE
VSPHERE_ISO_FILE
VSPHERE_REST_SESSION_PATH
VSPHERE_TEMPLATE
VSPHERE_TEMPLATE_COREOS
VSPHERE_TEMPLATE_ISO_TRANSPORT
VSPHERE_TEMPLATE_WINDOWS
VSPHERE_USE_LINKED_CLONE
VSPHERE_VIM_SESSION_PATH
VSPHERE_VM_V1_PATH
```

### Acceptance Tests

Then run acceptance tests from the root of this repository:

```
make testacc TEST=./vsphere
```
