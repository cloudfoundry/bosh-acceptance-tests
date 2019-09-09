#!/bin/bash

source bats-warden.env


bundle exec rspec spec/system $BAT_RSPEC_FLAGS
