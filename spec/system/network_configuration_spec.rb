require 'system/spec_helper'

describe 'network configuration' do
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

  context 'when using manual networking', manual_networking: true do
    it 'changes static IP address', changing_static_ip: true, ssh: true do
      use_second_static_ip
      deployment = with_deployment
      expect(bosh("-d #{deployment.name} deploy #{deployment.to_path}")).to succeed

      expect(bosh_ssh('batlight', 0, 'PATH=/sbin:/usr/sbin:$PATH; ifconfig', deployment: deployment.name).output).to include(second_static_ip)
    end

    it 'deploys multiple manual networks', multiple_manual_networks: true, ssh: true do
      use_multiple_manual_networks
      deployment = with_deployment
      expect(bosh("-d #{deployment.name} deploy #{deployment.to_path}")).to succeed

      expect(bosh_ssh('batlight', 0, 'PATH=/sbin:/usr/sbin:$PATH; ifconfig', deployment: deployment.name).output).to include(static_ips[0])
      expect(bosh_ssh('batlight', 0, 'PATH=/sbin:/usr/sbin:$PATH; ifconfig', deployment: deployment.name).output).to include(static_ips[1])
    end
  end
end
