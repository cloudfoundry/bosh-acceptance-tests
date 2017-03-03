#!/usr/bin/env bash

set -e

source /etc/profile.d/chruby.sh
chruby 2.1.7

function fromEnvironment() {
  local key="$1"
  local environment=environment/metadata
  cat $environment | jq -r "$key"
}

export BOSH_internal_cidr=$(fromEnvironment '.PublicCIDR')
export BOSH_az=$(fromEnvironment '.AvailabilityZone')
export BOSH_internal_gw=$(fromEnvironment '.PublicGateway')
export BOSH_internal_ip=$(fromEnvironment '.StaticIP1')
export BOSH_reserved_range="[$(fromEnvironment '.ReservedRange')]"
export BOSH_subnet_id=$(fromEnvironment '.PublicSubnetID')
export BOSH_default_security_groups="[$(fromEnvironment '.SecurityGroupID')]"

export BOSH_local_aws_cpi_release="cpi-release/release.tgz"

cat > director-creds.yml <<EOF
internal_ip: $BOSH_internal_ip
EOF

export bosh_cli=$(realpath bosh-cli/bosh-cli-*)
chmod +x $bosh_cli

$bosh_cli interpolate bats/ci/assets/ssh_key.yml --vars-store=/tmp/ssh_keystore

$bosh_cli interpolate bosh-deployment/bosh.yml \
  -o bosh-deployment/aws/cpi.yml \
  -o bats/ci/assets/local-aws-cpi-release.yml \
  --vars-store director-creds.yml \
  -v director_name=bats-director \
  -v private_key=$($bosh_cli interpolate /tmp/ssh_keystore --path=/private_key/private_key) \
  --vars-env "BOSH" > director.yml

$bosh_cli create-env director.yml -l director-creds.yml

# occasionally we get a race where director process hasn't finished starting
# before nginx is reachable causing "Cannot talk to director..." messages.
sleep 10

export BOSH_ENVIRONMENT=`$bosh_cli int director-creds.yml --path /internal_ip`
export BOSH_CA_CERT=`$bosh_cli int director-creds.yml --path /director_ssl/ca`
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`$bosh_cli int director-creds.yml --path /admin_password`

$bosh_cli -n update-cloud-config bosh-deployment/aws/cloud-config.yml \
          --ops-file bats/ci/assets/reserve-ips.yml \
          --vars-env "BOSH"

mv $HOME/.bosh director-state/
mv director.yml director-creds.yml director-state.json director-state/
