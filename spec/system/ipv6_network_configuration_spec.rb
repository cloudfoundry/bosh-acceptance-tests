require 'system/spec_helper'
require 'json'
require 'ipaddr'

describe 'IPv6 network configuration', ipv6: true do
  before(:all) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
  end

  before(:all) do
    load_deployment_spec
    use_static_ip
    use_vip
    @requirements.requirement(deployment, @spec)
  end

  after(:all) do
    @requirements.cleanup(deployment)
  end

  context 'when using manual networking and ipv6', ipv6_manual_networking: true do
    let(:deployment) do
      use_multiple_manual_networks
      with_deployment
    end

    it 'supports manual network dual stack on AWS', ipv6_dual_stack: true, ssh: true do
      expect(bosh("-d #{deployment.name} deploy #{deployment.to_path}")).to succeed

      output = bosh_ssh('batlight', 0, 'PATH=/sbin:/usr/sbin:$PATH; ifconfig', deployment: deployment.name).output
      expect(output).to include(static_ips[0])
      expect(output).to include(static_ips[1])
    end
  end

  context 'when allocating IPv6 prefix', ipv6_prefix_allocation: true do
    let(:deployment) do
      use_multiple_manual_networks
      with_deployment
    end

    before do
      expect(bosh("-d #{deployment.name} deploy #{deployment.to_path}")).to succeed
    end

    it 'returns the expected IPv6 prefix from AWS metadata', ssh: true do
      cli_cmd = 'mac=$(cat /sys/class/net/eth0/address);output_data=$(curl -s "http://169.254.169.254/latest/meta-data/network/interfaces/macs/$mac/ipv6-prefix");echo "----$output_data----"'
      prefix_output = bosh_ssh('batlight', 0, cli_cmd, deployment: deployment.name).output
      _, prefix = extract_ssh_stdout_between_dashes(prefix_output).split('/')

      expect(prefix).to eq('80')
    end

    it 'verifies the IPv6 prefix in spec.json', ssh: true do
      cli_cmd = 'mac=$(cat /sys/class/net/eth0/address);output_data=$(curl -s "http://169.254.169.254/latest/meta-data/network/interfaces/macs/$mac/ipv6-prefix");echo "----$output_data----"'
      prefix_output = bosh_ssh('batlight', 0, cli_cmd, deployment: deployment.name).output
      ip, prefix = extract_ssh_stdout_between_dashes(prefix_output).split('/')

      cli_cmd = 'output_data=$(sudo cat /var/vcap/bosh/spec.json); echo "----$output_data----"'
      spec_output = bosh_ssh('batlight', 0, cli_cmd, deployment: deployment.name).output

      json_str = extract_ssh_stdout_between_dashes(spec_output)
      spec = JSON.parse(json_str)
      found = spec['networks'].values.any? do |net|
        IPAddr.new(net['ip']) == IPAddr.new(ip) && net['prefix'].to_s == prefix.to_s
      end
      expect(found).to be true
    end
  end
end
