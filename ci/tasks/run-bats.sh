#!/usr/bin/env bash

set -e -x

source /etc/profile.d/chruby.sh
chruby 2.1.2

source bosh-concourse-ci/pipelines/$cpi_release_name/$base_os-exports.sh

eval $(ssh-agent)
chmod go-r $BAT_VCAP_PRIVATE_KEY
ssh-add $BAT_VCAP_PRIVATE_KEY

bosh -n target $BAT_DIRECTOR

sed -i.bak s/"uuid: replace-me"/"uuid: $(bosh status --uuid)"/ $BAT_DEPLOYMENT_SPEC

cd bats
bundle install
bundle exec rspec spec
