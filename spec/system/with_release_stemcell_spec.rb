require 'system/spec_helper'

describe 'with release and stemcell and subsequent deployments' do
  before(:all) do
    @requirements.requirement(@requirements.release)
    @requirements.requirement(@requirements.stemcell)
    load_deployment_spec
  end

  context 'with no ephemeral disk' do
    before do
      skip 'only openstack is configurable without ephemeral disk' unless @requirements.stemcell.supports_root_partition?

      reload_deployment_spec
      # using password 'foobar'
      use_password('$6$tHAu4zCTso$pAQok0MTHP4newel7KMhTzMI4tQrAWwJ.X./fFAKjbWkCb5sAaavygXAspIGWn8qVD8FeT.Z/XN4dvqKzLHhl0')
      @our_ssh_options = ssh_options.merge(password: 'foobar')
      use_static_ip
      use_vip
      use_job('batlight')
      use_templates(%w[batlight])

      use_flavor_with_no_ephemeral_disk

      @requirements.requirement(deployment, @spec)
    end

    after do |example|
      check_for_failure(@spec_state, example)
      @requirements.cleanup(deployment)
    end

    it 'creates ephemeral and swap partitions on the root device if no ephemeral disk', ssh: true do
      setting_value = agent_config(public_ip).
        fetch('Platform', {}).
        fetch('Linux', {}).
        fetch('CreatePartitionIfNoEphemeralDisk', false)

      skip 'root disk ephemeral partition requires a stemcell with CreatePartitionIfNoEphemeralDisk enabled' unless setting_value

      # expect ephemeral mount point to be a mounted partition on the root disk
      expect(mounts(public_ip)).to include(hash_including('path' => '/var/vcap/data'))

      # expect swap to be a mounted partition on the root disk
      expect(swaps(public_ip)).to include(hash_including('type' => 'partition'))
    end

    def agent_config(ip)
      output = ssh_sudo(ip, 'vcap', 'cat /var/vcap/bosh/agent.json', @our_ssh_options)
      JSON.parse(output)
    end

    def mounts(ip)
      output = ssh(ip, 'vcap', 'mount', @our_ssh_options)
      output.lines.map do |line|
        matches = /(?<point>.*) on (?<path>.*) type (?<type>.*) \((?<options>.*)\)/.match(line)
        next if matches.nil?
        matchdata_to_h(matches)
      end.compact
    end

    def swaps(ip)
      output = ssh(ip, 'vcap', 'swapon -s', @our_ssh_options)
      output.lines.to_a[1..-1].map do |line|
        matches = /(?<point>.+)\s+(?<type>.+)\s+(?<size>.+)\s+(?<used>.+)\s+(?<priority>.+)/.match(line)
        next if matches.nil?
        matchdata_to_h(matches)
      end.compact
    end

    def matchdata_to_h(matchdata)
      Hash[matchdata.names.zip(matchdata.captures)]
    end
  end

  context 'with ephemeral and persistent disk' do
    before(:all) do
      reload_deployment_spec
      # using password 'foobar'
      use_password('$6$tHAu4zCTso$pAQok0MTHP4newel7KMhTzMI4tQrAWwJ.X./fFAKjbWkCb5sAaavygXAspIGWn8qVD8FeT.Z/XN4dvqKzLHhl0')
      @our_ssh_options = ssh_options.merge(password: 'foobar')
      use_static_ip
      use_vip
      @jobs = %w[
        /var/vcap/packages/batlight/bin/batlight
        /var/vcap/packages/batarang/bin/batarang
      ]
      use_job('colocated')
      use_templates(%w[batarang batlight])

      use_persistent_disk(2048) unless rackhd?

      @requirements.requirement(deployment, @spec)
    end

    after(:all) do
      @requirements.cleanup(deployment)
    end

    it 'should set vcap password', ssh: true, core: true do
      ssh_command = "echo #{@env.vcap_password} | sudo -p '' -S whoami"
      expect(bosh_ssh('colocated', 0, ssh_command).output).to match /root/
    end

    it 'should not change the deployment on a noop', core: true do
      deployment_result = bosh('deploy')
      events(get_task_id(deployment_result.output)).each do |event|
        if event['stage']
          expect(event['stage']).to_not match(/^Updating/)
        end
      end
    end

    it 'should use job colocation', ssh: true, core: true do
      @jobs.each do |job|
        ssh_command = "ps -ef | grep #{job} | grep -v grep"
        expect(bosh_ssh('colocated', 0, ssh_command).output).to match /#{job}/
      end
    end

    it 'should have network access to the vm using the manual static ip' do
      skip "not applicable for dynamic networking" if dynamic_networking?

      vm = wait_for_vm('colocated/0')
      expect(vm).to_not be_nil
      expect(static_ip).to_not be_nil
      expect(ssh(public_ip, 'vcap', 'hostname', @our_ssh_options)).to match /#{vm[:agent_id]}/
    end

    it 'should have network access to the vm using the vip', core: true do
      skip "vip network isn't supported" unless includes_vip?

      vm = wait_for_vm('colocated/0')
      expect(vm).to_not be_nil
      expect(vip).to_not be_nil
      expect(ssh(vip, 'vcap', 'hostname', @our_ssh_options)).to match /#{vm[:agent_id]}/
    end

    context 'changing the persistent disk size' do
      SAVE_FILE = '/var/vcap/store/batarang/save'

      before(:all) do
        ssh(public_ip, 'vcap', "echo 'foobar' > #{SAVE_FILE}", @our_ssh_options)
        unless warden?
          @size = persistent_disk('colocated', 0)
        end
        use_persistent_disk(4096)
        @requirements.requirement(deployment, @spec, force: true)
      end

      it 'should migrate disk contents', ssh: true do
        # Warden df don't work so skip the persistent disk size check
        unless warden?
          expect(persistent_disk('colocated', 0)).to_not eq(@size)
        end
        expect(ssh(public_ip, 'vcap', "cat #{SAVE_FILE}", @our_ssh_options)).to match /foobar/
      end
    end
  end
end
