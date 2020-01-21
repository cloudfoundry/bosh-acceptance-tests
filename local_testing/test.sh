#!/bin/bash

set -euo pipefail

CUR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${CUR_DIR}/bats-warden.env"

pushd "${CUR_DIR}/.."
  bundle exec rspec spec/system "${BAT_RSPEC_FLAGS[@]}"
popd
