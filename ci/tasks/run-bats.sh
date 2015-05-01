#!/usr/bin/env bash

set -e -x

cd cpi-release

echo "working dir: `pwd`"
echo "...contains: `ls -la`"

env

# bundle exec rake spec:system:existing_micro[aws,xen,ubuntu,trusty,manual,go,true,raw
# NOTE: would require that we place artifacts at something like...
# /tmp/ci-artifacts/aws/manual/ubuntu/trusty/go/deployments
# WORKING/ci-artifacts/aws/manual/ubuntu/trusty/go/deployments


# Interesting parts of what actually happens...

# task :existing_micro, [
# 	:infrastructure_name, :hypervisor_name,
# 	:operating_system_name, :operating_system_version,
#   :net_type, :agent_name, :light, :disk_format do |_, args|
# Bosh::Dev::BatHelper.for_rake_args(args).run_bats

# Bosh::Dev::Aws::RunnerBuilder.build(artifacts, net_type)
# ...
# runner = Bosh::Dev::Bat::Runner.new(
#   env, artifacts, director_address,
#   bosh_cli_session, stemcell_archive,
#   microbosh_deployment_manifest, bat_deployment_manifest,
#   microbosh_deployment_cleaner, logger)
#
# runner.run_bats
# ... -->
#   Rake::Task['bat'.invoke
#   ... -->
#     Dir.chdir('bat') { exec('rspec', 'spec') }
