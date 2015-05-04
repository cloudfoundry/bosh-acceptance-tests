#!/usr/bin/env bash

set -e -x

cd bats
bundle install
bundle exec rspec spec