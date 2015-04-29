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

cd $basedir
echo "destroying existing BOSH..."
$initexe delete $manifest_path
echo "deploying BOSH..."
$initexe deploy $manifest_path

echo "checking in BOSH deployment state"
cd $basedir/bosh-deployments
git checkout master
git add concourse/bats-pipeline/*.json
git commit -m ":airplane: Concourse auto-updating deployment state for bats pipeline" --author="bosh-ci <cf-bosh-eng+bosh-ci@pivotal.io>"
