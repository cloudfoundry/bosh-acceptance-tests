#!/usr/bin/env bash

set -e -x

env
cd bats
bundle install
bundle exec rspec spec