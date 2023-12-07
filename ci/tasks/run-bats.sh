#!/usr/bin/env bash

set -e

export BAT_STEMCELL=$(realpath stemcell/*.tgz)
export BAT_DEPLOYMENT_SPEC=$(realpath bats-config/bats-config.yml)
export BAT_BOSH_CLI=$(realpath bosh-cli/*bosh-cli-*)
chmod +x $BAT_BOSH_CLI

source bats-config/bats.env

pushd $(realpath bats)
  bundle install
  bundle exec rspec spec $BAT_RSPEC_FLAGS
popd
