#!/usr/bin/env bash

set -e -x

semver=`cat version-semver/number`

echo "normalizing cpi release filename to value referenced in $manifest_path"
mv bosh-cpi-dev-artifacts/$cpi_release_name-$semver.tgz ./tmp/$cpi_release_name.tgz

initver=$(cat bosh-init/version)
initexe="$PWD/bosh-init/bosh-init-${initver}-linux-amd64"
chmod +x $initexe

echo "deleting existing BOSH Director VM..."
$initexe delete $manifest_path

echo "deploying BOSH..."
$initexe deploy $manifest_path

echo "checking in BOSH deployment state"
pushd bosh-deployments
git checkout master
git add concourse/bats-pipeline/*.json
git config --global user.email "cf-bosh-eng+bosh-ci@pivotal.io"
git config --global user.name "bosh-ci"
git commit -m ":airplane: Concourse auto-updating deployment state for bats pipeline"
popd
