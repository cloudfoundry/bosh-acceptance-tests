require 'spec_helper'
require 'logger'
require 'yaml'
require 'fileutils'
require 'tempfile'
require 'resolv'
require 'common/exec'

require 'bat/env'
require 'bat/bosh_runner'
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
env = Bat::Env.from_env
spec_state = Bat::SpecState.new(env.debug_mode)
bosh_runner = Bat::BoshRunner.new(ENV['BAT_BOSH_CLI'], logger)
requirements = Bat::Requirements.new(env.stemcell_path, bosh_runner, spec_state, logger)

RSpec.configure do |config|
  config.include(Bat::BoshHelper)
  config.include(Bat::DeploymentHelper)
  config.include(Bat::SpecStateHelper)

  # inject dependencies into tests
  config.before(:all) do
    @logger = logger
    @env = env
    @requirements = requirements
    @bosh_runner = bosh_runner
    @spec_state = spec_state
  end
end

RSpec.configure do |config|
  # Preload stemcell and release for tests that need it (most of them)
  config.before(:suite) do
    requirements.requirement(requirements.stemcell) # 2 min on local vsphere
    requirements.requirement(requirements.release)
  end

  config.after(:suite) do
    requirements.cleanup(requirements.stemcell)
    requirements.cleanup(requirements.release)
  end

  if env.debug_mode
    logger.debug('Debug mode is turned on, failing fast')
    config.fail_fast = true
  end

  config.after(:each) do |example|
    check_for_failure(spec_state, example)
  end
end

RSpec.configure do |config|
  config.before do |example|
    unless example.metadata[:skip_task_check]
      requirements.requirement(:no_tasks_processing) # 5 sec on local vsphere
    end
  end
end
