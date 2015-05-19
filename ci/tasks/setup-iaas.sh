#!/usr/bin/env bash

set -e -x

semver=`cat terraform-state-version/number`

bats/iaas_setup/$cpi_release_name/setup.sh semver bats/iaas_setup/$cpi_release_name
