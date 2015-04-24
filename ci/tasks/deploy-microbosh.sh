#!/usr/bin/env bash

set -e -x

dir=$PWD

echo "working dir: `pwd`"
ls -la *

echo "manifest: $manifest_path"
cat $manifest_path


export PATH=$dir/bosh-init:$PATH
