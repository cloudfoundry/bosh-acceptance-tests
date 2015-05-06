#!/usr/bin/env bash

set -e -x

eval $(ssh-agent)
chmod go-r bosh-deployments/keys/bosh-dev.key
ssh-add bosh-deployments/keys/bosh-dev.key

bosh target $BAT_DIRECTOR
export BOSH_USER="admin"
export BOSH_PASSWORD="admin"
bosh login

export BAT_DEPLOYMENT_SPEC=$PWD/bats_config.yml
cat << EOF > $BAT_DEPLOYMENT_SPEC
---
cpi: aws
properties:
  vip: 52.0.147.194
  second_static_ip: 10.10.0.30
  uuid: $(bosh status --uuid)
  pool_size: 1
  stemcell:
    name: bosh-aws-xen-ubuntu-trusty-go_agent
    version: latest
  instances: 1
  key_name:  bosh-dev
  networks:
    - name: default
      static_ip: 10.10.0.29
      type: manual
      cidr: 10.10.0.0/24
      reserved: [10.10.0.2-10.10.0.9]
      static: [10.10.0.10-10.10.0.30]
      gateway: 10.10.0.1
      subnet: subnet-015e6d47
      security_groups: [bat]
EOF

cd bats
bundle install
bundle exec rspec spec
