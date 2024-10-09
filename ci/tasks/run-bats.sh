#!/usr/bin/env bash

set -e

export BAT_STEMCELL=$(realpath stemcell/*.tgz)
export BAT_DEPLOYMENT_SPEC=$(realpath bats-config/bats-config.yml)
export BAT_BOSH_CLI=$(realpath "$(which bosh)")

source bats-config/bats.env

pushd $(realpath bats)
  bundle install
  bundle exec rspec spec $BAT_RSPEC_FLAGS
popd
