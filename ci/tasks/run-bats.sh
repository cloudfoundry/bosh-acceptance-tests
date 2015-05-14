#!/usr/bin/env bash

set -e -x

export BAT_VCAP_PRIVATE_KEY=$PWD/bosh-dev.key

eval $(ssh-agent)

set +x
echo "Saving private key data to $BAT_VCAP_PRIVATE_KEY"
echo "$aws_bats_ssh_private_key" > $BAT_VCAP_PRIVATE_KEY
set -x

chmod go-r $BAT_VCAP_PRIVATE_KEY
ssh-add $BAT_VCAP_PRIVATE_KEY

export BAT_DIRECTOR=52.4.218.25
export BAT_DNS_HOST=52.4.218.25
export BAT_STEMCELL=/tmp/build/src/stemcell/stemcell.tgz
export BAT_INFRASTRUCTURE=aws
export BAT_NETWORKING=manual
export BAT_VCAP_PASSWORD='c1oudc0w'
export BAT_DEPLOYMENT_SPEC=$PWD/bats_config.yml

bosh -n target $BAT_DIRECTOR
cat << EOF > $BAT_DEPLOYMENT_SPEC
---
cpi: aws
properties:
  vip: 52.6.255.151
  second_static_ip: 10.0.0.30
  uuid: $(bosh status --uuid)
  pool_size: 1
  stemcell:
    name: bosh-aws-xen-ubuntu-trusty-go_agent
    version: latest
  instances: 1
  key_name:  bosh-dev
  networks:
    - name: default
      static_ip: 10.0.0.29
      type: manual
      cidr: 10.0.0.0/24
      reserved: [10.0.0.2-10.0.0.9]
      static: [10.0.0.10-10.0.0.30]
      gateway: 10.0.0.1
      subnet: subnet-beba20e7
      security_groups: [bat]
EOF

cd bats
bundle install
bundle exec rspec spec
