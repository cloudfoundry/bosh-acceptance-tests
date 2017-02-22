require 'common/exec'

module Bat
  class BoshRunner

    def initialize(executable, cli_config_path, director_user, director_password, logger)
      @executable = executable
      @cli_config_path = cli_config_path
      @director_user = director_user
      @director_password = director_password
      @logger = logger
    end

    def bosh(arguments, options = {})
      command_options = {}
      if options[:deployment]
        command_options[:deployment] = options.delete(:deployment)
      end
      command = build_command(arguments, command_options)
      begin
        @logger.info("Running bosh command --> #{command}")
        result = Bosh::Exec.sh(command, options)
      rescue Exception => e
        if e.is_a?(Bosh::Exec::Error)
          @logger.info("Bosh command failed: #{e.output}")
        end
        if e.message.include?('closed stream')
          @logger.info("Error is close stream. Ignoring.... #{e.message}")
        else
          raise
        end
      end

      @logger.info(result.output)
      yield result if block_given?

      result
    end

    def bosh_safe(command, options = {})
      bosh(command, options.merge(on_error: :return))
    end

    def set_environment(director_url)
      @environment = director_url
    end

    private

    def build_command(arguments, options = {})
      command = []
      command << "#{@executable} --non-interactive"
      command << "--environment #{@environment}" if @environment
      command << '--json'
      command << "--config #{@cli_config_path}"
      command << "--client #{@director_user} --client-secret #{@director_password}"
      command << "--deployment #{options[:deployment]}" if options[:deployment]
      command << arguments

      command << '2>&1'

      command.join(' ')
    end

    def deploy_command?(arguments)
      arguments == 'deploy' || arguments.start_with?('deploy ')
    end

    def append_deploy_options(command)
      command << '--no-redact'
    end
  end
end
