#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby 2.1.7

export bosh_cli=$(realpath bosh-cli/bosh-cli-*)
chmod +x $bosh_cli

director_state="$PWD/director-state"
director_creds=${director_state}/director-creds.yml

$bosh_cli delete-env ${director_state}/director.yml -l $director_creds
