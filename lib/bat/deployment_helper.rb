require 'tmpdir'
require 'logger'

module Bat
  module DeploymentHelper
    def deployment
      load_deployment_spec
      @deployment ||= Bat::Deployment.new(@spec)
    end

    def reload_deployment_spec
      @spec = nil
      load_deployment_spec
    end

    def load_deployment_spec
      @spec ||= Psych.load_file(@env.deployment_spec_path)
      # Always set the batlight.missing to something, or deployments will fail.
      # It is used for negative testing.
      @spec['properties']['batlight'] ||= {}
      @spec['properties']['batlight']['missing'] = 'nope'
      # dup the job_network so test-local mutations don't affect other tests
      @spec['properties']['job_networks'] = [@spec['properties']['networks'].first.dup]
    end

    # if with_deployment() is called without a block, it is up to the caller to
    # remove the generated deployment file
    # @return [Bat::Deployment]
    def with_deployment(spec = {}, &block)
      deployment = Bat::Deployment.new(@spec.merge(spec))

      if !block_given?
        return deployment
      elsif block.arity == 1
        yield deployment
      else
        raise "unknown arity: #{block.arity}"
      end
    ensure
      if block_given?
        deployment.delete if deployment
      end
    end

    def with_tmpdir
      dir = nil
      back = Dir.pwd
      Dir.mktmpdir do |tmpdir|
        dir = tmpdir
        Dir.chdir(dir)
        yield dir
      end
    ensure
      Dir.chdir(back)
      FileUtils.rm_rf(dir) if dir
    end

    def use_instance_group(instance_group_name)
      @spec['properties']['instance_group_name'] = instance_group_name
    end

    def use_jobs(jobs)
      @spec['properties']['jobs'] = Array(jobs)
    end

    def use_instance_count(count)
      @spec['properties']['instances'] = count
    end

    def use_deployment_name(name)
      @spec['properties']['name'] = name
    end

    def use_additional_dns_server(dns_server)
      # Make sure working dns is the first entry in resolv.conf
      @spec['properties']['dns'] = [@env.dns_host, dns_server]
    end

    def deployment_name
      @spec.fetch('properties', {}).fetch('name', 'bat')
    end

    def use_vip
      @spec['properties']['use_vip'] = true
    end

    def no_vip
      @spec['properties']['use_vip'] = false
    end

    # Not necessarily a *public* ip, as it may fall back to
    # the static ip which is actually private.
    def public_ip
      # For AWS and OpenStack, the elastic IP is the public IP
      # For vSphere and vCloud, the static_ip is the public IP
      @spec['properties']['vip'] || static_ip
    end

    def use_static_ip
      @spec['properties']['use_static_ip'] = true
    end

    def no_static_ip
      @spec['properties']['use_static_ip'] = false
    end

    def static_ip
      static_ips.first
    end

    def vip
      @spec['properties']['vip']
    end

    def static_ips
      @spec['properties']['job_networks'].inject([]) do |memo, network|
        if network['type'] == 'manual'
          memo << network['static_ip']
        end
        memo
      end
    end

    def use_second_static_ip
      @spec['properties']['use_static_ip'] = true
      @spec['properties']['job_networks'][0]['static_ip'] = second_static_ip
    end

    def second_static_ip
      @spec['properties']['second_static_ip']
    end

    def use_multiple_manual_networks
      @spec['properties']['job_networks'] = []
      @spec['properties']['networks'].each do |network|
        if network['type'] == 'manual'
          # dup the job_networks so test-local mutations don't affect other tests
          @spec['properties']['job_networks'] << network.dup
        end
      end
    end

    def use_raw_instance_storage
      @spec['properties']['raw_instance_storage'] = 'true'
    end

    def use_persistent_disk(size)
      @spec['properties'].delete('persistent_disks')
      @spec['properties']['persistent_disk'] = size
    end

    def use_multiple_persistent_disks(*sizes)
      disks = []
      sizes.each do |size|
        name = "abc#{SecureRandom.hex(3)}"
        disks << {'name' => name, 'disk_size' => size}
      end
      @spec['properties']['disk_types'] = disks
      @spec['properties'].delete('persistent_disk')
      @spec['properties']['persistent_disks'] = disks.map { |v| {'name' => "xyz#{SecureRandom.hex(3)}", 'type' => v['name']} }
    end

    def use_canaries(count)
      @spec['properties']['canaries'] = count
    end

    def use_pool_size(size)
      @spec['properties']['pool_size'] = size
    end

    def use_failing_job
      @spec['properties']['batlight']['fail'] = 'control'
    end

    def use_flavor_with_no_ephemeral_disk
      @spec['properties']['instance_type'] = @spec['properties']['flavor_with_no_ephemeral_disk']
    end

    def network_type
      @spec['properties'].fetch('network', {}).fetch('type', nil)
    end

    def get_most_recent_task_id
      output = @bosh_runner.bosh("tasks --recent=1").output
      JSON.parse(output)["Tables"].first["Rows"].first["id"]
    end

    def events(task_id, expected_task_status = 'done')
      result = @bosh_runner.bosh_safe("task #{task_id} --event")
      if expected_task_status == 'error'
        expect(result).to_not succeed
      else
        expect(result).to succeed
      end

      expect(result.output).to match /Task #{task_id} #{expected_task_status}/

      event_list = []
      result.output.split("\n").each do |line|
        event = parse_json_safely(line)
        event_list << event if event
      end
      event_list
    end

    def start_and_finish_times_for_job_updates(task_id)
      jobs = {}
      events(task_id).select do |e|
        e['stage'] == 'Updating job' && %w(started finished).include?(e['state'])
      end.each do |e|
        jobs[e['task']] ||= {}
        jobs[e['task']][e['state']] = e['time']
      end
      jobs
    end

    private

    def spec
      @spec ||= {}
    end

    def parse_json_safely(line)
      JSON.parse(line)
    rescue JSON::ParserError => e
      @logger.info("Failed to parse '#{line}': #{e.inspect}")
      nil
    end
  end
end
