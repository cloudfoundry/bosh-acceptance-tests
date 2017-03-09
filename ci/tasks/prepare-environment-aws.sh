#!/bin/bash

set -e

export AWS_ACCESS_KEY_ID=$BOSH_access_key_id
export AWS_SECRET_ACCESS_KEY=$BOSH_secret_access_key
export AWS_DEFAULT_REGION=$BOSH_region
export bosh_cli=$(realpath bosh-cli/bosh-cli-*)
chmod +x $bosh_cli

source /etc/profile.d/chruby.sh
chruby 2.1.7

OUTPUT_DIR='bats-config'
SSH_KEY_PATH="$OUTPUT_DIR/ssh_key.pem"

KEYPAIR_NAME=$(cat environment/metadata | jq --raw-output .BlobstoreBucket | rev | cut -d '-' -f1,2 | rev)

aws ec2 delete-key-pair --key-name $KEYPAIR_NAME
aws ec2 create-key-pair --key-name $KEYPAIR_NAME > /tmp/keypair

cat /tmp/keypair | jq --raw-output .KeyMaterial > $SSH_KEY_PATH

function fromEnvironment() {
  local key="$1"
  local environment=environment/metadata
  cat $environment | jq -r "$key"
}

INTERNAL_CIDR=$(fromEnvironment '.PublicCIDR')
AZ=$(fromEnvironment '.AvailabilityZone')
INTERNAL_GW=$(fromEnvironment '.PublicGateway')
INTERNAL_IP=$(fromEnvironment '.DirectorStaticIP')
STATIC_IP_1=$(fromEnvironment '.StaticIP1')
STATIC_IP_2=$(fromEnvironment '.StaticIP2')
RESERVED_RANGE="$(fromEnvironment '.ReservedRange')"
SUBNET_ID=$(fromEnvironment '.PublicSubnetID')
STATIC_RANGE=$(fromEnvironment '.StaticRange')
DEFAULT_SECURITY_GROUPS="$(fromEnvironment '.SecurityGroupID')"

export BOSH_internal_cidr=${INTERNAL_CIDR}
export BOSH_az=${AZ}
export BOSH_internal_gw=${INTERNAL_GW}
export BOSH_internal_ip=${INTERNAL_IP}
export BOSH_reserved_range="[${RESERVED_RANGE}]"
export BOSH_subnet_id=${SUBNET_ID}
export BOSH_default_security_groups="[${DEFAULT_SECURITY_GROUPS}]"
export BOSH_default_key_name="${KEYPAIR_NAME}"
export BOSH_local_aws_cpi_release="/tmp/release.tgz"
export BOSH_elastic_ip=$(fromEnvironment '.DirectorEIP')

cat > $OUTPUT_DIR/director-creds.yml <<EOF
internal_ip: $BOSH_internal_ip
elastic_ip: $BOSH_elastic_ip
EOF

#TODO use stemcell

$bosh_cli interpolate bosh-deployment/bosh.yml \
  -o bosh-deployment/aws/cpi.yml \
  -o bats/ci/assets/local-aws-cpi-release.yml \
  -o bats/ci/assets/director_eip.yml \
  --vars-store $OUTPUT_DIR/director-creds.yml \
  -v director_name=bats-director \
  --var-file private_key=$SSH_KEY_PATH \
  --vars-env "BOSH" > $OUTPUT_DIR/director.yml

DIRECTOR_EIP=$(fromEnvironment '.DirectorEIP')
BATS_EIP=$(fromEnvironment '.DeploymentEIP')
SUBNET_ID=$(fromEnvironment '.PublicSubnetID')
SECURITY_GROUP=$(fromEnvironment '.SecurityGroupID')
BOSH_CLIENT=admin
BOSH_CLIENT_SECRET=$($bosh_cli int $OUTPUT_DIR/director-creds.yml --path=/admin_password)

cat > "${OUTPUT_DIR}/ca" <<EOF
$($bosh_cli int $OUTPUT_DIR/director-creds.yml --path /director_ssl/ca)
EOF

cat > "${OUTPUT_DIR}/bats.env" <<EOF
export BAT_DIRECTOR=${DIRECTOR_EIP}
export BAT_DNS_HOST=${DIRECTOR_EIP}
export BAT_INFRASTRUCTURE=aws
export BAT_NETWORKING=manual
export BAT_VCAP_PASSWORD="c1oudc0w"
export BAT_VCAP_PRIVATE_KEY=${SSH_KEY_PATH}
export BAT_VIP=${BATS_EIP}
export BAT_SUBNET_ID=${SUBNET_ID}
export BAT_SECURITY_GROUP_NAME=${SECURITY_GROUP}
export BAT_RSPEC_FLAGS="--tag ~multiple_manual_networks --tag ~root_partition"
export BAT_DIRECTOR_USER="${BOSH_CLIENT}"
export BAT_DIRECTOR_PASSWORD="${BOSH_CLIENT_SECRET}"
EOF

# BATs spec generation
cat > "${OUTPUT_DIR}/bats-config.yml" <<EOF
---
cpi: aws
properties:
  vip: ${BATS_EIP}
  second_static_ip: ${STATIC_IP_2}
  uuid: ((bosh_uuid))
  pool_size: 1
  stemcell:
    name: ${STEMCELL_NAME}
    version: latest
  instances: 1
  availability_zone: ${AZ}
  key_name:  ${KEYPAIR_NAME}
  networks:
    - name: default
      static_ip: ${STATIC_IP_1}
      type: manual
      cidr: ${INTERNAL_CIDR}
      reserved: [${RESERVED_RANGE}]
      static: [${STATIC_RANGE}]
      gateway: ${INTERNAL_GW}
      subnet: ${SUBNET_ID}
      security_groups: [${DEFAULT_SECURITY_GROUPS}]
EOF

$bosh_cli -n interpolate bosh-deployment/aws/cloud-config.yml \
          --ops-file bats/ci/assets/reserve-ips.yml \
          --vars-env "BOSH" > ${OUTPUT_DIR}/cloud-config.yml
