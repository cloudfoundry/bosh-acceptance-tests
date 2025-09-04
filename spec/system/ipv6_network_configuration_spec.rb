require 'system/spec_helper'
require 'json'
require 'ipaddr'

describe 'IPv6 network configuration', ipv6: true do
  before(:all) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
    load_deployment_spec
    use_static_ip
    use_vip

    @deployment = use_multiple_manual_networks
    @deployment = with_deployment
  end

  after(:all) do
    @requirements.cleanup(@deployment) if @deployment
  end

  context 'when using manual networking and ipv6', ipv6_manual_networking: true do
    before(:all) do
      @requirements.requirement(@deployment, @spec)
    end

    it 'supports manual network dual stack', dual_stack: true, ssh: true do
      output = bosh_ssh('batlight', 0, 'PATH=/sbin:/usr/sbin:$PATH; ifconfig', deployment: @deployment.name).output
      expect(output).to include(static_ips[0])
      expect(output).to include(static_ips[1])
    end
  end

  context 'when allocating IPv6 prefix', ipv6_prefix_allocation: true do
    before(:all) do
      network_prefixes
      skip 'Skipping IPv6 prefix allocation tests because a prefix is not configured under a network' unless @spec['properties']['job_prefixes'].to_a.any?
      @requirements.requirement(@deployment, @spec)
    end

    it 'returns the expected IPv6 prefix from metadata', ssh: true do
      _, prefix = fetch_ipv6_and_prefix_from_metadata('batlight', 0, @deployment.name)
      expect(prefix).not_to be_nil, "Could not fetch IPv6 prefix from metadata"
      expect(prefix).to eq('80')
    end

    it 'verifies the IPv6 prefix in spec.json', ssh: true do
      ip, prefix = fetch_ipv6_and_prefix_from_metadata('batlight', 0, @deployment.name)
      expect(ip).not_to be_nil, "Could not fetch IPv6 address from metadata"
      expect(prefix).not_to be_nil, "Could not fetch IPv6 prefix from metadata"

      cli_cmd = 'output_data=$(sudo cat /var/vcap/bosh/spec.json); echo "----$output_data----"'
      spec_output = bosh_ssh('batlight', 0, cli_cmd, deployment: @deployment.name).output

      json_str = extract_ssh_stdout_between_dashes(spec_output)
      spec = JSON.parse(json_str)
      found = spec['networks'].values.any? do |net|
        IPAddr.new(net['ip']) == IPAddr.new(ip) && net['prefix'].to_s == prefix.to_s
      end
      expect(found).to eq(true), "IPv6 address #{ip}/#{prefix} not found in spec.json networks"
    end
  end
end
