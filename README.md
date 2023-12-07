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

#### manual networking

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
    static_ip: 10.10.0.30
    cidr: 10.10.0.0/24
    reserved: ['10.10.0.2 - 10.10.0.9']
    static: ['10.10.0.10 - 10.10.0.31']
    gateway: 10.10.0.1
    subnet: subnet-xxxxxxxx # VPC subnet
    security_groups: 'bat' # VPC security groups
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
