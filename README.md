# BOSH Acceptance Tests

The BOSH Acceptance Tests are meant to be used to verify the commonly used functionality of BOSH.

BATs describe BOSH behavior at the highest level. They often cover infrastructure-specific behavior that is not easily tested at lower levels. BATs verify integration between all BOSH components and infrastructures. They run against a deployed Director and use the CLI to perform tasks. They exercise different BOSH workflows (e.g. deploying for the first time, updating existing deployments, handling broken deployments). The assertions are made against CLI commands exit status, output and state of VMs after performing the command. Since BATs run on real infrastructures, they help verify that specific combinations of the Director and stemcell works.

## Prerequisites

- deployed BOSH director
- installed BOSH v2 cli 

## Configure BATS

### Required Environment Variables

Before you can run BAT, you need to set the following environment variables:

```
# path to the stemcell you want to use for testing
export BAT_STEMCELL=

# path to the bat yaml file which is used to generate the deployment manifest (see below `bat.yml`)
export BAT_DEPLOYMENT_SPEC=

# BOSH CLI executable path
export BAT_BOSH_CLI=bosh

# the name of infrastructure that is used by bosh deployment. Examples: aws, vsphere, openstack, warden, oci.
export BAT_INFRASTRUCTURE=

# Run tests with --fail-fast and skip cleanup in case of failure (optional)
export BAT_DEBUG_MODE=
```

#### Environment variables for the BOSH v2 cli

Provide all necessary variables for the BOSH cli to connect to the director, e.g.:

```
export BOSH_ENVIRONMENT=<director ip or alias to bosh-env>
export BOSH_CLIENT=<director username>
export BOSH_CLIENT_SECRET=<director password>
export BOSH_CA_CERT=<director ca cert content or path>
export BOSH_ALL_PROXY=<socks5 proxy url needed to connect to bosh or deployed vms>
```

## BATS manifest: bat.yml

Create `bat.yml` that is used by BATs to generate manifest. Set `BAT_DEPLOYMENT_SPEC` to point to `bat.yml` file path.

The 'dns' property MUST NOT be specified in the BAT deployment spec properties. At all.

### AWS

#### manual networking (IPv6, IPv6 prefix, nic_groups, multiple manual networks)

```yaml
---
cpi: aws
properties:
  stemcell:
    name: bosh-aws-xen-ubuntu-trusty-go_agent
    version: latest
  instances: 1
  ssh_gateway:
    host: "jumpbox_host" # optional host used to provide tunnel when the tests need to ssh to VMs
    username: "jumpbox_username" # optional username used to provide tunnel when the tests need to ssh to VMs
  ssh_key_pair:
    public_key: "public_key_string" # used when deploying VMs to allow direct ssh access
    private_key: "private_key_string" # used to ssh into bosh deployed VMs and the gateway host
  vip: 54.54.54.54 # elastic ip for bat deployed VM
  second_static_ip: 10.10.0.31 # Secondary (private) IP to use for reconfiguring networks, must be in the primary network & different from static_ip
  networks:
  - name: default
    type: manual
    static_ip: 10.10.0.30
    cidr: 10.10.0.0/24
    reserved: ['10.10.0.2 - 10.10.0.9']
    static: ['10.10.0.10 - 10.10.0.31']
    gateway: 10.10.0.1
    subnet: subnet-xxxxxxxx # VPC subnet
    security_groups: 'bat' # VPC security groups
    nic_group: 1
  - name: second
    type: manual
    static_ip: 10.10.0.50
    cidr: 10.10.0.0/24
    reserved: ['10.10.0.33 - 10.10.0.39']
    static: ['10.10.0.40 - 10.10.0.51']
    gateway: 10.10.0.1
    subnet: subnet-xxxxxxxx
    security_groups: 'bat'
    nic_group: 2
  - name: ipv6
    type: manual
    static_ip: 2001:db8:abcd:1234::30
    cidr: 2001:db8:abcd:1234::/56
    reserved: ['2001:db8:abcd:1234::2 - 2001:db8:abcd:1234::f']
    static: [2001:db8:abcd:1234::10 - 2001:db8:abcd:1234::31]
    gateway: 2001:db8:abcd:1234::1
    subnet: subnet-xxxxxxxx
    security_groups: 'bat'
    nic_group: 1
  - name: prefix
    type: manual
    cidr: 2001:db8:abcd:1234::/56
    reserved: ['2001:db8:abcd:1234::2 - 2001:db8:abcd:1234::f']
    gateway: 2001:db8:abcd:1234::1
    prefix: 80
    subnet: subnet-xxxxxxxx
    security_groups: 'bat'
    nic_group: 1
  key_name: bosh # (optional) SSH keypair name, overrides the director's default_key_name setting
```

### OpenStack

#### dynamic networking

```yaml
---
cpi: openstack
properties:
  stemcell:
    name: bosh-openstack-kvm-ubuntu-trusty-go_agent
    version: latest
  instances: 1
  instance_type: some-ephemeral
  availability_zone: az1 # (optional)
  flavor_with_no_ephemeral_disk: no-ephemeral
  vip: 0.0.0.43 # Virtual (public/floating) IP assigned to the bat-release job vm ('static' network), for ssh testing
  networks:
  - name: default
    type: dynamic
    cloud_properties:
      net_id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx # Network ID
      security_groups: ['default'] # security groups assigned to deployed VMs
  key_name: bosh # (optional) SSH keypair name, overrides the director's default_key_name setting
```

#### manual networking

```yaml
---
cpi: openstack
properties:
  stemcell:
    name: bosh-openstack-kvm-ubuntu-trusty-go_agent
    version: latest
  instances: 1
  instance_type: some-ephemeral
  flavor_with_no_ephemeral_disk: no-ephemeral
  volume_type: premium # (optional) Volume type for persistent disks, defaults to 'gp2' if not specified
  vip: 0.0.0.43 # Virtual (public/floating) IP assigned to the bat-release job vm ('static' network), for ssh testing
  second_static_ip: 10.253.3.29 # Secondary (private) IP to use for reconfiguring networks, must be in the primary network & different from static_ip
  networks:
  - name: default
    type: manual
    static_ip: 10.0.1.30 # Primary (private) IP assigned to the bat-release job vm (primary NIC), must be in the primary static range
    cloud_properties:
      net_id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx # Primary Network ID
      security_groups: ['default'] # Security groups assigned to deployed VMs
    cidr: 10.0.1.0/24
    reserved: ['10.0.1.2 - 10.0.1.9']
    static: ['10.0.1.10 - 10.0.1.30']
    gateway: 10.0.1.1
  - name: second # Secondary network for testing jobs with multiple manual networks
    type: manual
    static_ip: 192.168.0.30 # Secondary (private) IP assigned to the bat-release job vm (secondary NIC)
    cloud_properties:
      net_id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx # Secondary Network ID
      security_groups: ['default'] # Security groups assigned to deployed VMs
    cidr: 192.168.0.0/24
    reserved: ['192.168.0.2 - 192.168.0.9']
    static: ['192.168.0.10 - 192.168.0.30']
    gateway: 192.168.0.1
  password: hash # (optional) vcap password hash
```

### vSphere

```yaml
---
cpi: vsphere
properties:
  stemcell:
    name: bosh-vsphere-esxi-ubuntu-trusty-go_agent
    version: latest
  instances: 1
  second_static_ip: 192.168.79.62 # Secondary (private) IP assigned to the bat-release job vm, used for testing network reconfiguration, must be in the primary network & different from static_ip
  datacenters:  # This whole block is optional, and the format should match what the CPI expects in an AZ's datacenters configuration block
  - name: myDC
    clusters:
    - myClusterName:
        resource_pool: myRP
  networks:
  - name: static
    type: manual
    static_ip: 192.168.79.61 # Primary (private) IP assigned to the bat-release job vm, must be in the static range
    cidr: 192.168.79.0/24
    reserved: ['192.168.79.2 - 192.168.79.50', '192.168.79.128 - 192.168.79.254'] # multiple reserved ranges are allowed but optional
    static: ['192.168.79.60 - 192.168.79.70']
    gateway: 192.168.79.1
    vlan: Network_Name # vSphere network name
```

### Oracle Cloud Infrastructure (OCI)
#### Manual networking

Example bat.yml pointed to by `BAT_DEPLOYMENT_SPEC` environment variable 

```yaml

---
cpi: oci 
properties:
  stemcell:
    name: light-oracle-ubuntu-stemcell 
    version: latest
  instances: 1
  instance_shape: 'VM.Standard1.2' # Instance shape
  availability_domain: WZYX:PHX-AD-3 

  networks:
  - name: default
    type: manual
    static_ip: 10.0.X.30 # Primary (private) IP assigned to the bat-release job vm (primary NIC), must be in the primary static range
    cloud_properties:
      vcn: cloudfoundry_vcn 
      subnet: private_subnet_ad3 
    cidr: 10.0.X.0/24 # CIDR bock of the subnet
    reserved: ['10.0.X.2 - 10.0.X.9'] # 
    static: ['10.0.X.10 - 10.0.X.30']
    gateway: 10.0.X.1
  - name: second # Secondary network for testing jobs with multiple manual networks
    type: manual
    static_ip: 10.0.Y.30 # Must be in the static range defined below
    cloud_properties:
      vcn: cloudfoundry_vcn 
      subnet: private_subnet_ad3_for_bats 
    cidr: 10.0.Y.0/24
    reserved: ['10.0.Y.2 - 10.0.Y.9']
    static: ['10.0.Y.10 - 10.0.Y.30']
    gateway: 10.0.Y.1
```

### Proxmox VE

#### manual networking

```yaml
---
cpi: pve
properties:
  stemcell:
    name: bosh-openstack-kvm-ubuntu-noble # PVE runs the OpenStack KVM stemcells; see Proxmox VE Setup below
    version: latest
  instances: 1
  vm_cores: 2 # (optional) cores for the BATs vm_type, defaults to 2
  vm_memory: 2048 # (optional) memory in MiB for the BATs vm_type, defaults to 2048
  vm_disk: 8192 # (optional) root disk in MiB for the BATs vm_type, defaults to 8192
  cpi_id: pve-az1 # (optional) cpi-config entry name, required when the director has a cpi-config applied
  second_static_ip: 10.0.1.31 # Secondary (private) IP to use for reconfiguring networks, must be in the primary network & different from static_ip
  ssh_key_pair:
    public_key: "public_key_string" # used when deploying VMs to allow direct ssh access
    private_key: "private_key_string" # used to ssh into bosh deployed VMs
  networks:
  - name: default
    type: manual
    static_ip: 10.0.1.30 # Primary (private) IP assigned to the bat-release job vm, must be in the static range
    cidr: 10.0.1.0/24
    reserved: ['10.0.1.2 - 10.0.1.9']
    static: ['10.0.1.30 - 10.0.1.39']
    gateway: 10.0.1.1
    cloud_properties:
      bridge: vmbr0 # PVE bridge or SDN vnet the deployed VMs attach to
      vlan: 100 # (optional) VLAN tag, 1-4094
```

## Setup IaaS

### AWS Setup

#### On EC2 with AWS-provided DHCP networking

Add TCP port `4567` to the **default** security group.

#### On EC2 with VPC networking

Create a **bat** security group in the same VPC the BAT_DIRECTOR is running in. Allow inbound access to TCP ports
 `22` and `4567` to the bat security group.

### OpenStack Setup

#### Networking Config

Add TCP ports `22` and `4567` to the **default** security group.

#### Flavors

Create the following flavors:

* `m1.small`
    * ephemeral disk > 6GB
    * root disk big enough for stemcell root partition (currently 3GB)
* `no-ephemeral`
    * ephemeral disk = 0
    * root disk big enough for stemcell root partition (currently 3GB), plus at least 1GB for ephemeral & swap partitions

### Proxmox VE Setup

#### Stemcells

There is no Proxmox VE stemcell on bosh.io. PVE guests are QEMU/KVM, so the OpenStack KVM stemcells run as they are:

```bash
bosh upload-stemcell https://bosh.io/d/stemcells/bosh-openstack-kvm-ubuntu-noble
```

Whatever `bosh stemcells` then lists is the name `bat.yml` must refer to. Do not assume the example above: current stemcells carry no `-go_agent` suffix, and a CPI that repacks the same image as a light stemcell publishes it under a name of its own.

#### Networking Config

The machine running BATs needs to reach TCP ports `22` and `4567` on the deployed VMs. PVE has no security group concept, so with the firewall off there is nothing to configure.

With the firewall on, a bridge is not a firewall scope, so rules go on the guests. PVE filters a VM only when the datacenter master switch, the VM's own firewall option, and the firewall flag on that VM's network device are all enabled, so which of those the CPI sets decides what is left to do: where it leaves the per-device flag off, the VM is unfiltered and both ports are already reachable; where it sets the flag, add inbound TCP `22` and `4567` rules to the VM firewall or the deployed VMs are unreachable and every ssh example fails.

The `static` range in `bat.yml` must sit inside the subnet the bridge serves, and the addresses in it must not collide with the director or anything else on that subnet. List every conflicting address in `reserved`.

#### Runtime configs

BATs deploy a single job and the `os` tagged specs compare monit's process list against that job's own pid, so the deployment must be free of runtime-config addons. Scope every addon on the director away from the BATs deployment, for example:

```yaml
addons:
- name: my-addon
  exclude:
    deployments: [bat]
```

Without this, the pid file spec fails with `actual batlight pid (...) different from pid monitored by monit (...)` listing the addon's processes alongside batlight's.

#### Multiple CPIs

A director with a cpi-config applied rejects any AZ that does not name a CPI. Set `cpi_id` in `bat.yml` to the cpi-config entry BATs should deploy through; the template omits the key entirely when it is unset.

## Running BATS

Some tests in BATs may not be applicable to a given IaaS and can be skipped using tags.
BATs currently supports the following tags which are enabled by default (use `--tag ~vip_networking` to exclude them):

  - `core`: basic BOSH functionality which all CPIs should implement
  - `persistent_disk`: persistent disk lifecycle tests
  - `vip_networking`: static public address handling
  - `dynamic_networking`: IaaS provided address handling
  - `manual_networking`: BOSH Director specified address handling
  - `root_partition`: BOSH agent repartitioning of unused storage on root volume
  - `multiple_manual_networks`: support for creating machines with multiple network interfaces
  - `raw_ephemeral_storage`: BOSH agent exposes all attached instance storage to deployed jobs
  - `reboot`: reboot VM tests as part of cloud-check
  - `changing_static_ip`: `configure_networks` CPI method support [deprecated]

Here is an example of running BATs on vSphere, skipping tests that are not applicable.
Execute the following inside the bosh-acceptance-tests directory:

```
bundle exec rspec spec --tag ~vip_networking --tag ~dynamic_networking --tag ~root_partition --tag ~raw_ephemeral_storage
```

Here is the same for Proxmox VE on a lab with one IPv4 network. PVE has no floating IP concept and no raw instance storage, and its vm_types size the root disk explicitly, so those tags are skipped along with the ones the single network cannot cover:

```bash
bundle exec rspec spec --tag ~vip_networking --tag ~root_partition --tag ~raw_ephemeral_storage --tag ~raw_instance_storage --tag ~ipv6 --tag ~ipv6_manual_networking --tag ~ipv6_prefix_allocation --tag ~dual_stack --tag ~nic_groups --tag ~multiple_manual_networks
```

It is also possible to only execute specific tests like this:

```
bundle exec rspec spec --tag manual_networking --tag dynamic_networking
```
