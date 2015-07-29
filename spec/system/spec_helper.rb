require 'spec_helper'
require 'logger'
require 'yaml'
require 'fileutils'
require 'tempfile'
require 'resolv'
require 'common/exec'

require 'bat/env'
require 'bat/bosh_runner'
require 'bat/bosh_api'
require 'bat/requirements'
require 'bat/spec_state'
require 'bat/stemcell'
require 'bat/release'
require 'bat/deployment'
require 'bat/bosh_helper'
require 'bat/deployment_helper'

require File.expand_path('../support/succeed_matchers', __FILE__)

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
end

logger = Logger.new(STDOUT)
bosh_config_file = Tempfile.new('bosh_config')

env = Bat::Env.from_env

spec_state = Bat::SpecState.new(
  env.debug_mode
)

bosh_runner = Bat::BoshRunner.new(
  'bundle exec bosh',
  bosh_config_file.path,
  logger,
)

bosh_api = Bat::BoshApi.new(
  env.director,
  logger,
)

requirements = Bat::Requirements.new(
  env.stemcell_path,
  bosh_runner,
  bosh_api,
  spec_state,
  logger,
)

RSpec.configure do |config|
  config.include(Bat::BoshHelper)
  config.include(Bat::DeploymentHelper)

  # inject dependencies into tests
  config.before(:all) do
    @logger = logger
    @env = env
    @requirements = requirements
    @bosh_api = bosh_api
    @bosh_runner = bosh_runner
    @spec_state = spec_state
  end
end

RSpec.configure do |config|
  # Preload stemcell and release for tests that need it (most of them)
  config.before(:suite) do
    bosh_runner.bosh("target #{env.director}")
    requirements.requirement(requirements.stemcell) # 2 min on local vsphere
    requirements.requirement(requirements.release)
  end

  config.after(:suite) do
    requirements.cleanup(requirements.stemcell)
    requirements.cleanup(requirements.release)
  end

  if env.debug_mode
    config.fail_fast = true
  end

  config.after(:each) do |example|
    if example.exception
      @spec_state.register_fail
    end
  end
end

RSpec.configure do |config|
  config.before do |example|
    unless example.metadata[:skip_task_check]
      requirements.requirement(:no_tasks_processing) # 5 sec on local vsphere
    end
  end
end
