#!/bin/bash
# sets up an AWS account with the prerequisistes for running BATs

set -x -e

version=$1
terraform_dir=$2

#FIXME: add a terraform resource
sudo apt-get install unzip
wget https://dl.bintray.com/mitchellh/terraform/terraform_0.5.1_linux_amd64.zip
unzip terraform*.zip

./terraform plan -out=bats-dependencies.tfplan \
  -var "access_key=$access_key_id" \
  -var "secret_key=$secret_access_key" \
  -var "build_id=bats-$version" \
  -var "concourse_ip=52.4.241.132" \
  $terraform_dir

./terraform apply -state=bats-dependencies-${version}.tfstate bats-dependencies.tfplan
