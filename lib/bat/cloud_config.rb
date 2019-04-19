require 'erb'
require 'tempfile'
require 'yaml'

module Bosh; end # Ugly hack
require 'bosh/template/evaluation_context'

module Bat
  class CloudConfig
    def initialize(spec)
      @spec = spec
      generate_cloud_config(spec)
    end

    def name
      yaml['name']
    end

    def to_path
      path
    end

    def delete
      puts "<-- rm #{path}"
      FileUtils.rm_rf(File.dirname(to_path))
    end

    def generate_cloud_config(spec)
      puts "Generating cloud config with input:\n#{spec.to_yaml}"
      @context = Bosh::Template::EvaluationContext.new(spec, nil)
      erb = ERB.new(load_template(@context.spec.cpi))
      result = erb.result(@context.get_binding)
      begin
        @yaml = YAML.load(result)
        puts "Generated cloud config:\n#{@yaml.to_yaml}"
      rescue SyntaxError => e
        puts "Failed to parse cloud config:\n#{result}"
        raise e
      end
      store_cloud_config(result)
    end

    private

    attr_reader :path, :yaml

    def store_cloud_config(content)
      cloud_config = tempfile('cloud_config')
      cloud_config.write(content)
      cloud_config.close
      @path = cloud_config.path
    end

    def load_template(cpi)
      template = File.expand_path("../../../templates/cloud_config_#{cpi}.yml.erb", __FILE__)
      File.read(template)
    end

    def tempfile(name)
      File.open(File.join(Dir.mktmpdir, name), 'w')
    end

    def to_s
      "#{name}"
    end
  end
end
