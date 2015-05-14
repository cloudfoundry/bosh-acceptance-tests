#!/usr/bin/env bash

set -e -x

semver=`cat version-semver/number`

echo "normalizing cpi release filename to value referenced in $manifest_path"
mkdir ./tmp
mv bosh-cpi-dev-artifacts/$cpi_release_name-$semver.tgz ./tmp/$cpi_release_name.tgz

initver=$(cat bosh-init/version)
initexe="$PWD/bosh-init/bosh-init-${initver}-linux-amd64"
chmod +x $initexe

manifest_path=bosh-deployments/concourse/$cpi_release_name/director-manifest.yml

echo "deleting existing BOSH Director VM..."
$initexe delete $manifest_path

echo "deploying BOSH..."
$initexe deploy $manifest_path
