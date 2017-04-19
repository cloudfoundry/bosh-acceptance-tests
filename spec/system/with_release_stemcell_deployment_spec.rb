require 'system/spec_helper'

describe 'with release, stemcell and deployment', core: true do
  before(:all) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
  end

  before(:all) do
    load_deployment_spec
    use_static_ip
    use_vip
    @requirements.requirement(deployment, @spec) # 2.5 min on local vsphere
  end

  after(:all) do
    @requirements.cleanup(deployment)
  end

  describe 'agent' do
    before do
      bosh('update-resurrection off')
    end

    after do
      bosh('update-resurrection on')
    end

    it 'should survive agent dying', ssh: true do
      Dir.mktmpdir do |tmpdir|
        ssh_command="sudo pkill -9 agent"
        expect(bosh_ssh('batlight', 0, ssh_command, deployment: deployment.name)).to succeed
        wait_for_instance_state('batlight', '0', 'running')
        expect(bosh_safe("logs batlight/0 --agent --dir #{tmpdir}", deployment: deployment.name)).to succeed
      end
    end
  end

  describe 'ssh' do
    it 'can bosh ssh into a vm' do
      expect(bosh_ssh('batlight', 0, "uname -a", deployment: deployment.name).output).to match /Linux/
    end
  end

  describe 'job' do
    it 'should recreate a job' do
      old_vm_cid = JSON.parse(bosh_safe('instances --details', deployment: deployment.name).output)['Tables'].first['Rows'].first["vm_cid"]
      expect(bosh_safe('recreate batlight/0', deployment: deployment.name)).to succeed
      new_vm_cid = JSON.parse(bosh_safe('instances --details', deployment: deployment.name).output)['Tables'].first['Rows'].first["vm_cid"]
      expect(old_vm_cid).not_to eq(new_vm_cid)
    end

    it 'should stop and start a job' do
      expect(bosh_safe('stop batlight/0', deployment: deployment.name)).to succeed
      bosh_instances = bosh_safe('instances', deployment: deployment.name).output
      batlight_0_process_state = JSON.parse(bosh_instances)['Tables'].first['Rows'].first["process_state"]
      expect(batlight_0_process_state).to match("stopped")

      expect(bosh_safe('start batlight/0', deployment: deployment.name)).to succeed
      bosh_instances = bosh_safe('instances', deployment: deployment.name).output
      batlight_0_process_state = JSON.parse(bosh_instances)['Tables'].first['Rows'].first["process_state"]
      expect(batlight_0_process_state).to match("running")
    end
  end

  describe 'logs' do
    it 'should get agent log' do
      with_tmpdir do
        expect(bosh_safe('logs batlight/0 --agent', deployment: deployment.name)).to succeed_with /Downloading resource/
        files = tar_contents(tarfile)
        expect(files).to include './current'
      end
    end

    it 'should get job logs' do
      with_tmpdir do
        expect(bosh_safe('logs batlight/0', deployment: deployment.name)).to succeed_with /Downloading resource/
        files = tar_contents(tarfile)
        expect(files).to include './batlight/batlight.stdout.log'
        expect(files).to include './batlight/batlight.stderr.log'
      end
    end
  end
end
