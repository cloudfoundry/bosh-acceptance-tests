#!/usr/bin/env bash

set -e -x

eval $(ssh-agent)
ssh-add bosh-deployments/keys/bosh-dev.pub

cd bats
bundle install
bundle exec rspec spec
