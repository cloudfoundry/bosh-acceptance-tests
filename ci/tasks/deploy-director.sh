#!/usr/bin/env bash

set -e

bats_config="$PWD/bats-config"

export bosh_cli=$(realpath bosh-cli/bosh-cli-*)
chmod +x $bosh_cli

DIRECTOR_CREDS=$bats_config/director-creds.yml

cp cpi-release/*.tgz /tmp/release.tgz

$bosh_cli create-env $bats_config/director.yml -l $DIRECTOR_CREDS

# occasionally we get a race where director process hasn't finished starting
# before nginx is reachable causing "Cannot talk to director..." messages.
sleep 10

export BOSH_ENVIRONMENT=`$bosh_cli int $DIRECTOR_CREDS --path /elastic_ip`
export BOSH_CA_CERT=`$bosh_cli int $DIRECTOR_CREDS --path /director_ssl/ca`
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`$bosh_cli int $DIRECTOR_CREDS --path /admin_password`

$bosh_cli -n update-cloud-config $bats_config/cloud-config.yml

mv $HOME/.bosh director-state/
cp $bats_config/director.yml $DIRECTOR_CREDS $bats_config/director-state.json director-state/
