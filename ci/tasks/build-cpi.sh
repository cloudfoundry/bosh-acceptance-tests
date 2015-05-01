#!/usr/bin/env bash

set -e -x

echo "building CPI release..."
pushd cpi-release
bosh create release --name $cpi_release_name --version 0.0.0 --with-tarball
popd
mv cpi-release/dev_releases/$cpi_release_name/$cpi_release_name-0.0.0.tgz $cpi_release_name.tgz
