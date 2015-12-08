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
      bosh('vm resurrection batlight 0 off')
    end

    after do
      bosh('vm resurrection batlight 0 on')
    end

    xit 'should survive agent dying', ssh: true do
      Dir.mktmpdir do |tmpdir|
        ssh_command="echo #{@env.vcap_password} | sudo -S pkill -9 agent"
        expect(bosh_ssh('batlight', 0, ssh_command)).to succeed
        wait_for_vm_state('batlight', '0', 'running')
        expect(bosh_safe("logs batlight 0 --agent --dir #{tmpdir}")).to succeed
      end
    end
  end

  describe 'ssh' do
    it 'can bosh ssh into a vm' do
      expect(bosh_ssh('batlight', 0, "uname -a").output).to match /Linux/
    end
  end

  describe 'job' do
    it 'should recreate a job' do
      expect(bosh_safe('recreate batlight 0')).to succeed_with /batlight\/0 recreated/
    end

    it 'should stop and start a job' do
      expect(bosh_safe('stop batlight 0')).to succeed_with /batlight\/0 stopped/
      expect(bosh_safe('start batlight 0')).to succeed_with /batlight\/0 started/
    end
  end

  describe 'logs' do
    it 'should get agent log' do
      with_tmpdir do
        expect(bosh_safe('logs batlight 0 --agent')).to succeed_with /Logs saved in/
        files = tar_contents(tarfile)
        expect(files).to include './current'
      end
    end

    it 'should get job logs' do
      with_tmpdir do
        expect(bosh_safe('logs batlight 0')).to succeed_with /Logs saved in/
        files = tar_contents(tarfile)
        expect(files).to include './batlight/batlight.stdout.log'
        expect(files).to include './batlight/batlight.stderr.log'
      end
    end
  end
end
