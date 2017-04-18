require 'system/spec_helper'

describe 'with release and stemcell and subsequent deployments' do
  before(:all) do
    @requirements.requirement(@requirements.release)
    @requirements.requirement(@requirements.stemcell)
    load_deployment_spec
  end

  context 'with no ephemeral disk', root_partition: true do
    before do
      reload_deployment_spec
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

    it 'creates ephemeral and swap partitions on the root device if no ephemeral disk', ssh: true, core: true do
      setting_value = agent_config().
        fetch('Platform', {}).
        fetch('Linux', {}).
        fetch('CreatePartitionIfNoEphemeralDisk', false)

      skip 'root disk ephemeral partition requires a stemcell with CreatePartitionIfNoEphemeralDisk enabled' unless setting_value

      # expect ephemeral mount point to be a mounted partition on the root disk
      expect(mounts()).to include(hash_including('path' => '/var/vcap/data'))

      # expect swap to be a mounted partition on the root disk
      expect(swaps()).to include(hash_including('type' => 'partition'))
    end

    def agent_config
      output = bosh_ssh('batlight', 0, 'sudo cat /var/vcap/bosh/agent.json', deployment: deployment.name, result: true, column: 'stdout').output
      JSON.parse(output)
    end

    def mounts
      output = bosh_ssh('batlight', 0, 'mount', deployment: deployment.name, result: true, column: 'stdout').output
      output.lines.map do |line|
        matches = /(?<point>.*) on (?<path>.*) type (?<type>.*) \((?<options>.*)\)/.match(line)
        next if matches.nil?
        matchdata_to_h(matches)
      end.compact
    end

    def swaps
      output = bosh_ssh('batlight', 0, 'swapon -s', deployment: deployment.name, result: true, column: 'stdout').output
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

  context 'with persistent disk size changing', persistent_disk: true do
    SAVE_FILE = '/var/vcap/store/batarang/save'

    before(:all) do
      reload_deployment_spec
      use_static_ip
      use_vip
      @jobs = %w[
        /var/vcap/packages/batlight/bin/batlight
        /var/vcap/packages/batarang/bin/batarang
      ]
      use_job('colocated')
      use_templates(%w[batarang batlight])
      use_persistent_disk(2048)

      @requirements.requirement(deployment, @spec)

      bosh_ssh('colocated', 0, "sudo sh -c \"echo 'foobar' > #{SAVE_FILE}\"", deployment: deployment.name)
      unless warden?
        @size = persistent_disk('colocated', 0, deployment: deployment)
      end
      use_persistent_disk(4096)
      @requirements.requirement(deployment, @spec, force: true)
    end

    after(:all) do
      @requirements.cleanup(deployment)
    end

    it 'should migrate disk contents', ssh: true do
      # Warden df don't work so skip the persistent disk size check
      unless warden?
        expect(persistent_disk('colocated', 0, deployment: deployment)).to_not eq(@size)
      end
      expect(bosh_ssh('colocated', 0, "cat #{SAVE_FILE}", deployment: deployment.name).output).to match /foobar/
    end
  end

  describe 'general stemcell configuration' do
    before(:all) do
      reload_deployment_spec
      # using password 'foobar'
      use_password('$6$tHAu4zCTso$pAQok0MTHP4newel7KMhTzMI4tQrAWwJ.X./fFAKjbWkCb5sAaavygXAspIGWn8qVD8FeT.Z/XN4dvqKzLHhl0')
      use_static_ip
      use_vip
      @jobs = %w[
        /var/vcap/packages/batlight/bin/batlight
        /var/vcap/packages/batarang/bin/batarang
      ]
      use_job('colocated')
      use_templates(%w[batarang batlight])

      @requirements.requirement(deployment, @spec)
    end

    after(:all) do
      @requirements.cleanup(deployment)
    end

    # this test case will not test password for vcap correctly after changing to bosh_ssh.
    # even with ssh, if we set private_key in our ssh_option, we still failing testing password.
    it 'should set vcap password', ssh: true, core: true do
      expect(bosh_ssh('colocated', 0, 'sudo whoami', deployment: deployment.name).output).to match /root/
    end

    it 'should not change the deployment on a noop', core: true do
      bosh("deploy #{deployment.to_path}", deployment: deployment.name)
      events(get_most_recent_task_id).each do |event|
        if event['stage']
          expect(event['stage']).to_not match(/^Updating/)
        end
      end
    end

    it 'should use job colocation', ssh: true, core: true do
      @jobs.each do |job|
        ssh_command = "ps -ef | grep #{job} | grep -v grep"
        expect(bosh_ssh('colocated', 0, ssh_command, deployment: deployment.name).output).to match /#{job}/
      end
    end

    it 'should have network access to the vm using the manual static ip', manual_networking: true do
      instance = wait_for_instance_state('colocated', '0', 'running')
      expect(instance).to_not be_nil
      expect(static_ip).to_not be_nil
      expect(bosh_ssh('colocated', 0, 'hostname', deployment: deployment.name).output).to match /#{instance[:agent_id]}/
    end

    it 'should have network access to the vm using the vip', vip_networking: true do
      instance = wait_for_instance_state('colocated', '0', 'running')
      expect(instance).to_not be_nil
      expect(vip).to_not be_nil
      expect(bosh_ssh('colocated', 0, 'hostname', deployment: deployment.name).output).to match /#{instance[:agent_id]}/
    end
  end
end
