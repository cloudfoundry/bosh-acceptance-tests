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

  describe 'resolving DNS entries', dns: true do
    let(:dns) { Resolv::DNS.new(nameserver: @env.dns_host) }
    
    it 'forward looks up instance' do
      address = nil
      expect {
        address = dns.getaddress("0.batlight.default.bat.#{bosh_tld}").to_s
      }.not_to raise_error, 'this test tries to resolve to the public IP of director, so you need to have incoming UDP enabled for it'
      expect(address).to eq(public_ip_v2)
    end

    it 'reverse looks up instance' do
      names = dns.getnames(public_ip_v2)
      expect(names.to_s).to include("0.batlight.default.bat.#{bosh_tld}.")
    end

    it 'resolves instance names from deployed VM' do
      # Temporarily add to debug why dig is returning 'connection timed out'
      resolv_conf = bosh_ssh('batlight', 0, 'cat /etc/resolv.conf').output
      @logger.info("Contents of resolv.conf '#{resolv_conf}'")

      bosh('logs batlight 0 --agent --dir /tmp')

      cmd = 'dig +short 0.batlight.default.bat.bosh a 0.batlight.default.bat.microbosh a'
      expect(bosh_ssh('batlight', 0, cmd).output).to include(public_ip_v2)
    end
  end

  describe 'changing instance DNS', dns: true, network_reconfiguration: true do
    let(:manifest_with_different_dns) do
      # Need to include a valid DNS host so that other tests
      # can still use dns resolution on the deployed VM
      use_additional_dns_server('127.0.0.5')
      with_deployment
    end

    after { manifest_with_different_dns.delete }

    it 'successfully reconfigures VM with new DNS nameservers' do
      expect(bosh("deployment #{manifest_with_different_dns.to_path}")).to succeed
      expect(bosh('deploy')).to succeed
      expect(bosh_ssh('batlight', 0, 'cat /etc/resolv.conf').output).to include('127.0.0.5')
    end
  end

  context 'when using manual networking', manual_networking: true do
    it 'changes static IP address', changing_static_ip: true do
      use_second_static_ip
      deployment = with_deployment
      expect(bosh("deployment #{deployment.to_path}")).to succeed
      expect(bosh('deploy')).to succeed

      expect(bosh_ssh('batlight', 0, 'PATH=/sbin:/usr/sbin:$PATH; ifconfig').output).to include(second_static_ip)
    end

    it 'deploys multiple manual networks', multiple_manual_networks: true do
      use_multiple_manual_networks
      deployment = with_deployment
      expect(bosh("deployment #{deployment.to_path}")).to succeed
      expect(bosh('deploy')).to succeed

      expect(bosh_ssh('batlight', 0, 'PATH=/sbin:/usr/sbin:$PATH; ifconfig').output).to include(static_ips[0])
      expect(bosh_ssh('batlight', 0, 'PATH=/sbin:/usr/sbin:$PATH; ifconfig').output).to include(static_ips[1])
    end
  end
end
