#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby 2.1.7

export bosh_cli=$(realpath bosh-cli/bosh-cli-*)
chmod +x $bosh_cli

cp cpi-release/*.tgz /tmp/release.tgz

director_state="$PWD/director-state"
director_creds=${director_state}/director-creds.yml

export BOSH_ENVIRONMENT=`$bosh_cli int $director_creds --path /elastic_ip`
export BOSH_CA_CERT=`$bosh_cli int $director_creds --path /director_ssl/ca`
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`$bosh_cli int $director_creds --path /admin_password`

set +e

$bosh_cli delete-deployment -n -d $deployment_name
$bosh_cli clean-up --all
$bosh_cli delete-env -n ${director_state}/director.yml -l $director_creds
