require 'erb'
require 'tempfile'
require 'yaml'

module Bosh; end # Ugly hack
require 'bosh/template/evaluation_context'

module Bat
  class Deployment
    def initialize(spec)
      @spec = spec
      generate_deployment_manifest(spec)
    end

    def name
      yaml['name']
    end

    def to_path
      path
    end

    def delete
      puts "<-- rm #{path}"
      FileUtils.rm_rf(File.dirname(to_path)) unless keep?
    end

    def generate_deployment_manifest(spec)
      puts "Generating deployment manifest with input:\n#{spec.to_yaml}"
      @context = Bosh::Template::EvaluationContext.new(spec, nil)
      erb = ERB.new(load_template(spec['manifest_template_path']))
      result = erb.result(@context.get_binding)
      begin
        @yaml = YAML.load(result)
        puts "Generated deployment manifest:\n#{@yaml.to_yaml}"
      rescue SyntaxError => e
        puts "Failed to parse deployment manifest:\n#{result}"
        raise e
      end
      store_manifest(result)
    end

    private

    attr_reader :path, :yaml

    def store_manifest(content)
      manifest = tempfile('deployment')
      manifest.write(content)
      manifest.close
      @path = manifest.path
    end

    def load_template(path)
      if path
        template = path
      else
        template = File.expand_path("../../../templates/deployment.yml.erb", __FILE__)
      end

      File.read(template)
    end

    def tempfile(name)
      File.open(File.join(Dir.mktmpdir, name), 'w')
    end

    def keep?
      ENV['BAT_MANIFEST'] == 'keep'
    end

    def to_s
      "#{name}"
    end
  end
end
