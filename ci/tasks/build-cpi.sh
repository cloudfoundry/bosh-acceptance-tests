#!/usr/bin/env bash

set -e -x

echo "installing BOSH CLI"
gem install bosh_cli --no-ri --no-rdoc

echo "building CPI release..."
pushd cpi-release
bosh create release --name $CPI_RELEASE_NAME --version 0.0.0 --with-tarball
popd
mv cpi-release/dev_releases/$CPI_RELEASE_NAME/$CPI_RELEASE_NAME-0.0.0.tgz cpi-release.tgz
