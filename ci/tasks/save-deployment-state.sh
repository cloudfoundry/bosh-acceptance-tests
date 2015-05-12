#!/usr/bin/env bash

set -e -x

echo "checking in BOSH deployment state"
cd deploy-bosh/bosh-deployments
git checkout master
git add concourse/bats-pipeline/*.json
git config --global user.email "cf-bosh-eng+bosh-ci@pivotal.io"
git config --global user.name "bosh-ci"
git commit -m ":airplane: Concourse auto-updating deployment state for bats pipeline"
