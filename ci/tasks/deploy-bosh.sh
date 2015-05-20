#!/usr/bin/env bash

set -e -x

source /etc/profile.d/chruby.sh
chruby 2.1.2

semver=`cat version-semver/number`
manifest_dir=bosh-concourse-ci/pipelines/$cpi_release_name
manifest_filename=$manifest_dir/$base_os-director-manifest.yml

echo "normalizing paths to match values referenced in $manifest_filename"
mkdir ./tmp
mv ./bosh-cpi-dev-artifacts/$cpi_release_name-$semver.tgz ./tmp/$cpi_release_name.tgz
mv ./bosh-release/release.tgz ./tmp/bosh-release.tgz
mv ./stemcell/stemcell.tgz ./tmp/stemcell.tgz
cp ./bosh-concourse-ci/pipelines/bosh-aws-cpi/bats.pem ./tmp/bats.pem

initver=$(cat bosh-init/version)
initexe="$PWD/bosh-init/bosh-init-${initver}-linux-amd64"
chmod +x $initexe

echo "deleting existing BOSH Director VM..."
$initexe delete $manifest_filename

echo "deploying BOSH..."
$initexe deploy $manifest_filename
