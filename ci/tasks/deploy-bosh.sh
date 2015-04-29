#!/usr/bin/env bash

set -e -x

basedir=$PWD

ls -la

boshdir=$basedir/bosh-src
initdir=$basedir/bosh-init
initver=$(cat $initdir/version)
initexe="bosh-init-${initver}-linux-amd64"

export PATH=$initdir:$PATH
export BUNDLE_GEMFILE=$boshdir/Gemfile

chmod +x $initdir/$initexe
# gem install bosh_cli --no-ri --no-rdoc
gem install bundler --no-ri --no-rdoc

echo "building CPI release..."
cd $basedir/cpi-release
bundle install
bundle exec bosh create release \
  --name cpi-release            \
  --version 0.0.0               \
  --with-tarball

echo "destroying existing BOSH..."
cd $basedir
$initexe delete $manifest_path

echo "deploying BOSH..."
cd $basedir
$initexe deploy $manifest_path

echo "checking in BOSH deployment state"
cd $basedir/bosh-deployments
git checkout master
git add concourse/bats-pipeline/*.json
git config --global user.email "cf-bosh-eng+bosh-ci@pivotal.io"
git config --global user.name "bosh-ci"
git commit -m ":airplane: Concourse auto-updating deployment state for bats pipeline"
