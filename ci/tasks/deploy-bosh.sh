#!/usr/bin/env bash

set -e -x

initver=$(cat bosh-init/version)
initexe="$PWD/bosh-init/bosh-init-${initver}-linux-amd64"
chmod +x $initexe

echo "deploying BOSH..."
$initexe deploy --update-if-exists $manifest_path

echo "checking in BOSH deployment state"
pushd bosh-deployments
git checkout master
git add concourse/bats-pipeline/*.json
git config --global user.email "cf-bosh-eng+bosh-ci@pivotal.io"
git config --global user.name "bosh-ci"
git commit -m ":airplane: Concourse auto-updating deployment state for bats pipeline"
popd