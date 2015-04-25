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

echo "building CPI release..."
cd cpi-release
bundle exec bosh create release \
  --name cpi-release            \
  --version 0.0.0               \
  --with-tarball                \
  --force                       \
  --final                       \
  --non-interactive

echo "deploying microbosh..."
cd $basedir
$initexe deploy $manifest_path
