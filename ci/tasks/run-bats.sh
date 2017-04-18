#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby 2.3.1

export BAT_STEMCELL=$(realpath stemcell/*.tgz)
export BAT_DEPLOYMENT_SPEC=$(realpath bats-config/bats-config.yml)
export BAT_BOSH_CLI=$(realpath bosh-cli/bosh-cli-*)
chmod +x $BAT_BOSH_CLI

source bats-config/bats.env

# todo disable host key checking for deployed VMs
mkdir -p $HOME/.ssh
cat > $HOME/.ssh/config << EOF
Host *
    StrictHostKeyChecking no
EOF

ssh_key_path=/tmp/bat_private_key
echo "$BAT_PRIVATE_KEY" > $ssh_key_path
chmod 600 $ssh_key_path

export BOSH_GW_PRIVATE_KEY=$ssh_key_path

pushd $(realpath bats)
  bundle install
  bundle exec rspec spec $BAT_RSPEC_FLAGS
popd
