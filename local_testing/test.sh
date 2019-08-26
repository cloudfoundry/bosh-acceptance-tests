#!/bin/bash

LOCAL_DEVELOPMENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

source ${LOCAL_DEVELOPMENT_DIR}/bats-warden.env


bundle exec rspec spec/system $BAT_RSPEC_FLAGS
