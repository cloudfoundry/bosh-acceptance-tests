require 'httpclient'
require 'json'
require 'net/ssh'
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

    def ssh_options
      {
        private_key: @env.vcap_private_key,
        password: @env.vcap_password
      }
    end

    def manual_networking?
      @env.bat_networking == 'manual'
    end

    def aws?
      @env.bat_infrastructure == 'aws'
    end

    def openstack?
      @env.bat_infrastructure == 'openstack'
    end

    def rackhd?
      @env.bat_infrastructure == 'rackhd'
    end

    def warden?
      @env.bat_infrastructure == 'warden'
    end

    def compiled_package_cache?
      info = @bosh_api.info
      info['features'] && info['features']['compiled_package_cache']
    end

    def dns?
      info = @bosh_api.info
      info['features'] && info['features']['dns']['status']
    end

    def bosh_tld
      info = @bosh_api.info
      info['features']['dns']['extras']['domain_name'] if dns?
    end

    def persistent_disk(job, index)
      get_disks(job, index).each do |disk|
        values = disk.last
        if values[:mountpoint] == '/var/vcap/store'
          return values[:blocks]
        end
      end
      raise 'Could not find persistent disk size'
    end

    def ssh(host, user, command, options = {})
      options = options.dup
      output = nil
      @logger.info("--> ssh: #{user}@#{host} #{command.inspect}")

      private_key = options.delete(:private_key)
      options[:user_known_hosts_file] = %w[/dev/null]
      options[:keys] = [private_key] unless private_key.nil?

      if options[:keys].nil? && options[:password].nil?
        raise 'Need to set ssh :password, :keys, or :private_key'
      end

      @logger.info("--> ssh options: #{options.inspect}")
      Net::SSH.start(host, user, options) do |ssh|
        output = ssh.exec!(command).to_s
      end

      @logger.info("--> ssh output: #{output.inspect}")
      output
    end

    def ssh_sudo(host, user, command, options)
      if options[:password].nil?
        raise 'Need to set sudo :password'
      end
      ssh(host, user, "echo #{options[:password]} | sudo -p '' -S #{command}", options)
    end

    def bosh_ssh(job, index, command)
      private_key = ssh_options[:private_key]

      # Try our best to clean out old host fingerprints for director and vms
      if File.exist?(File.expand_path('~/.ssh/known_hosts'))
        Bosh::Exec.sh("ssh-keygen -R '#{@env.director}'")
        Bosh::Exec.sh("ssh-keygen -R '#{static_ip}'")
      end

      if private_key
        bosh_ssh_options = {
          gateway_host: @env.director,
          gateway_user: 'vcap',
          gateway_identity_file: private_key,
        }.map { |k, v| "--#{k} '#{v}'" }.join(' ')

        # Note gateway_host + ip: ...fingerprint does not match for "micro.ci2.cf-app.com,54.208.15.101" (Net::SSH::HostKeyMismatch)
        if File.exist?(File.expand_path('~/.ssh/known_hosts'))
          Bosh::Exec.sh("ssh-keygen -R '#{@env.director},#{static_ip}'").output
        end
      end

      bosh_safe("ssh #{job} #{index} '#{command}' #{bosh_ssh_options}")
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

    def wait_for_vm(name)
      @logger.info("Start waiting for vm #{name}")
      vm = nil
      5.times do
        vm = get_vms.find { |v| v[:job_index] == name }
        break if vm
      end
      @logger.info("Finished waiting for vm #{name} vm=#{vm.inspect}")
      vm
    end

    private

    def get_vms
      output = @bosh_runner.bosh('vms --details').output
      table = output.lines.grep(/\|/)

      table = table.map { |line| line.split('|').map(&:strip).reject(&:empty?) }
      headers = table.shift || []
      headers.map! do |header|
        header.downcase.tr('/ ', '_').to_sym
      end
      output = []
      table.each do |row|
        output << Hash[headers.zip(row)]
      end
      output
    end

    def get_disks(job, index)
      disks = {}
      df_cmd = 'df -x tmpfs -x devtmpfs -x debugfs -l | tail -n +2'

      df_output = bosh_ssh(job, index, df_cmd)
      df_output.split("\n").each do |line|
        fields = line.split(/\s+/)
        disks[fields[0]] = {
          blocks: fields[1],
          used: fields[2],
          available: fields[3],
          percent: fields[4],
          mountpoint: fields[5],
        }
      end

      disks
    end
  end
end
