#!/usr/bin/env bash
set -euo pipefail

BAT_STEMCELL=$(realpath stemcell/*.tgz)
BAT_DEPLOYMENT_SPEC=$(realpath bats-config/bats-config.yml)
BAT_BOSH_CLI=$(realpath "$(command -v bosh)")
export BAT_STEMCELL
export BAT_DEPLOYMENT_SPEC
export BAT_BOSH_CLI

source bats-config/bats.env

pushd "$(realpath bats)"
  bundle install

  if declare -p BAT_RSPEC_FLAGS 2>/dev/null | grep -q 'declare \-a'; then
    bundle exec rspec spec "${BAT_RSPEC_FLAGS[@]}"
  else
    # shellcheck disable=SC2086
    bundle exec rspec spec ${BAT_RSPEC_FLAGS:-}
  fi
popd
