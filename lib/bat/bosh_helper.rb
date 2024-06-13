require 'httpclient'
require 'json'
require 'net/ssh'
require 'net/ssh/gateway'
require 'zlib'
require 'archive/tar/minitar'
require 'tempfile'
require 'common/exec'

module Bat
  module BoshHelper
    include Archive::Tar

    def bosh(*args, &blk)
      @bosh_runner.bosh(*args, &blk)
    end

    def bosh_safe(*args, &blk)
      @bosh_runner.bosh_safe(*args, &blk)
    end

    def ssh_options(spec)
      options = {
        private_key: spec['properties']['ssh_key_pair']['private_key']
      }
      if spec['properties']['ssh_gateway']
        options[:gateway_host] = spec['properties']['ssh_gateway']['host']
        options[:gateway_username] = spec['properties']['ssh_gateway']['username']
        options[:gateway_private_key] = spec['properties']['ssh_gateway']['private_key']
      end
      options
    end

    def aws?
      @env.bat_infrastructure == 'aws'
    end

    def openstack?
      @env.bat_infrastructure == 'openstack'
    end

    def warden?
      @env.bat_infrastructure == 'warden'
    end

    def vsphere?
      @env.bat_infrastructure == 'vsphere'
    end

    def persistent_disk(job, index, options)
      get_disks(job, index, options).each do |_, disk|
        return disk[:blocks] if disk[:mountpoint] == '/var/vcap/store'
      end
      raise 'Could not find persistent disk size'
    end

    def ssh(host, user, command, options = {})
      ssh_options = {}
      output = nil
      @logger.info("--> ssh: #{user}@#{host} #{command.inspect}")

      ssh_options[:user_known_hosts_file] = %w[/dev/null]

      raise 'Need to set ssh :private_key' if options[:private_key].nil?
      ssh_options[:key_data] = [options[:private_key]]

      @logger.info("--> ssh options: #{ssh_options.inspect}")

      if options[:gateway_host] && options[:gateway_username]
        gateway_ssh_options = ssh_options.dup
        if options[:gateway_private_key]
          gateway_ssh_options[:key_data] = [options[:gateway_private_key]]
        end

        gateway = Net::SSH::Gateway.new(
          options[:gateway_host],
          options[:gateway_username],
          gateway_ssh_options
        )
        local_port_for_gateway = gateway.open(host, 22)
        ssh_options[:port] = local_port_for_gateway
        host = '127.0.0.1'
      end

      Net::SSH.start(host, user, ssh_options) do |ssh|
        output = ssh.exec!(command).to_s
      end

      if gateway
        gateway.close(local_port_for_gateway)
      end

      @logger.info("--> ssh output: #{output.inspect}")
      output
    end

    def bosh_ssh(job, index, command, options = {})
      options[:json] = false
      column = options.delete(:column)

      bosh_ssh_options = ''
      bosh_ssh_options << '--results' if options.delete(:result)
      bosh_ssh_options << " --column=#{column}" if column
      bosh("ssh #{job}/#{index} -c '#{command}' #{bosh_ssh_options}", options)
      # TODO: we should consider using -r to get propper output
      # this means fixing al the other tests that rely on the current output
    end

    def service_command(job, index, deployment)
      agent_settings = agent_config(job, index, deployment)
      service_manager = agent_settings.dig('Platform', 'Linux', 'ServiceManager')

      service_manager == 'systemd' ? 'systemctl' : 'sv'
    end

    def agent_config(job, index, deployment)
      ssh_result = bosh_ssh(
        job,
        index,
        'sudo cat /var/vcap/bosh/agent.json',
        options: {
          column: 'stdout',
          deployment: deployment.name,
          result: true,
        }
      )

      JSON.parse(ssh_result.output)
    end

    def tarfile
      Dir.glob('*.tgz').first
    end

    def tar_contents(tgz, entries = false)
      list = []
      tar = Zlib::GzipReader.open(tgz)
      Minitar.open(tar).each do |entry|
        is_file = entry.file?
        entry = entry.name unless entries
        list << entry if is_file
      end
      list
    end

    def wait_for_process_state(name, index, state, wait_time_in_seconds=300)
      puts "Start waiting for instance #{name} to have process state #{state}"
      instance_in_state = nil
      10.times do
        instance = get_instance(name, index)
        if instance && instance['process_state'] =~ /#{state}/
          instance_in_state = instance
          break
        end
        sleep wait_time_in_seconds/10
      end
      if instance_in_state
        @logger.info("Finished waiting for instance #{name} have process state=#{state} instance=#{instance_in_state.inspect}")
        instance_in_state
      else
        raise Exception, "Instance is still not in expected process state: #{state}"
      end
    end

    def wait_for_instance_state(name, index, state, wait_time_in_seconds=300)
      puts "Start waiting for instance #{name} to have state #{state}"
      instance_in_state = nil
      10.times do
        instance = get_instance(name, index)
        if instance && instance['state'] =~ /#{state}/
          instance_in_state = instance
          break
        end
        sleep wait_time_in_seconds/10
      end
      if instance_in_state
        @logger.info("Finished waiting for instance #{name} have state=#{state} instance=#{instance_in_state.inspect}")
        instance_in_state
      else
        raise Exception, "Instance is still not in expected state: #{state}"
      end
    end

    private

    def get_instance(name, index)
      instance = get_instances.find do |i|
        i['instance'] =~ /#{name}\/[a-f0-9\-]{36}/ || i['instance'] =~ /#{name}\/#{index} \([a-f0-9\-]{36}\)/ && i['index'] == index
      end

      instance
    end

    def get_instances
      output = @bosh_runner.bosh('instances --details').output
      output_hash = JSON.parse(output)

      output_hash['Tables'][0]['Rows']
    end

    def get_disks(job, index, options)
      disks = {}
      df_cmd = 'df -x tmpfs -x devtmpfs -x debugfs -l | tail -n +2'

      options[:result] = true
      options[:json] = false
      options[:column] = 'stdout'

      df_output = bosh_ssh(job, index, df_cmd, options).output
      df_output.split("\n").each do |line|
        fields = line.split(/\s+/)
        disks[fields[0]] = {
          blocks: fields[1],
          used: fields[2],
          available: fields[3],
          percent: fields[4],
          mountpoint: fields[5]
        }
      end

      disks
    end

    def get_disk_cids(name, index)
      instance = get_instance(name, index)
      instance['disk_cids']
    end

    def get_agent_id(name, index)
      instance = get_instance(name, index)
      instance['agent_id']
    end

    def get_vm_cid(name, index)
      instance = get_instance(name, index)
      instance['vm_cid']
    end

    def unresponsive_agent_instance
      get_instances.find { |i| i['process_state'] == 'unresponsive agent' }
    end

    def unresponsive_agent_vm_cid
      unresponsive_agent_instance['vm_cid']
    end

    def vm_exists?(vm_cid)
      instance = get_instances.find { |i| i['vm_cid'] == vm_cid }
      return false if instance.nil?

      true
    end
  end
end
