require 'common/exec'
require 'base64'

module Bat
  class BoshRunner
    def initialize(executable, logger)
      @executable = executable
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

    def info
      bosh('env')
    end

    def deployments
      result = {}
      bosh('deployments')["Tables"][0]["Rows"].each { |r| result[r['name']] = true }
      result
    end

    def releases
      result = []
      bosh('releases')["Tables"][0]["Rows"].each do |r|
        result << Bat::Release.new(r['name'], [])
      end
      result
    end

    def stemcells
      result = []
      http_get('/stemcells').each do |s|
        result << Bat::Stemcell.new(s['name'], s['version'])
      end
      result
    end

    private

    def build_command(arguments, options = {})
      command = []
      command << "#{@executable} --non-interactive"
      command << '--json'
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
