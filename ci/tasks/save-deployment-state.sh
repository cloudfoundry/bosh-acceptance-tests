#!/usr/bin/env bash

set -e -x

manifest_dir=bosh-deployments/concourse/$cpi_release_name

echo "checking in BOSH deployment state"
cd deploy-bosh/$manifest_dir
git add director-manifest-state.json
git config --global user.email "cf-bosh-eng+bosh-ci@pivotal.io"
git config --global user.name "bosh-ci"
git commit -m ":airplane: Concourse auto-updating deployment state for bats pipeline"
