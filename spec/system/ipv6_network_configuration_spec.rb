require 'system/spec_helper'
require 'json'
require 'ipaddr'

describe 'IPv6 network configuration', ipv6: true do
  before(:all) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
    load_deployment_spec
  end

  context 'when using manual networking and ipv6', ipv6_manual_networking: true do
    before(:all) do
      use_static_ip
      use_multiple_manual_networks
      @deployment = with_deployment
      expect(bosh("-d #{@deployment.name} deploy #{@deployment.to_path}")).to succeed

      @requirements.requirement(@deployment, @spec)
    end

    after(:all) do
      @requirements.cleanup(@deployment) if @deployment
    end

    it 'supports manual network dual stack', dual_stack: true, ssh: true do
      output = bosh_ssh('batlight', 0, 'PATH=/sbin:/usr/sbin:$PATH; ifconfig', deployment: @deployment.name).output
      expect(output).to include(static_ips[0])
      expect(output).to include(static_ips[1])
    end
  end

  context 'when allocating IPv6 prefix', ipv6_prefix_allocation: true do
    before(:all) do
      load_deployment_spec
      use_multiple_manual_networks
      no_static_ip
      use_instance_count(2)

      if network_prefixes.empty?
        skip 'Skipping IPv6 prefix allocation tests because a prefix is not defined under a network'
      end

      @prefix_deployment = with_deployment
      expect(bosh("-d #{@prefix_deployment.name} deploy #{@prefix_deployment.to_path}")).to succeed

      @requirements.requirement(@prefix_deployment, @spec)
    end

    after(:all) do
      @requirements.cleanup(@prefix_deployment) if @prefix_deployment
    end

    it 'verifies the IPv6 prefix in spec.json', ssh: true do
      instances_prefix_ips = get_ipv6_prefix_addresses
      expect(instances_prefix_ips).not_to be_nil

      # Verify each instance's spec.json contains its assigned prefix
      instances_prefix_ips.each_with_index do |(instance, ip_with_prefix), index|
        ip, prefix = ip_with_prefix.split('/')
        instance_name, instance_id = instance.split('/')
        cli_cmd = 'output_data=$(sudo cat /var/vcap/bosh/spec.json); echo "----$output_data----"'
        spec_output = bosh_ssh(instance_name, instance_id, cli_cmd, deployment: @prefix_deployment.name).output
        json_str = extract_ssh_stdout_between_dashes(spec_output)
        spec = JSON.parse(json_str)

        found = spec['networks'].values.any? do |net|
          IPAddr.new(net['ip']) == IPAddr.new(ip) && net['prefix'].to_s == prefix.to_s
        end

        expect(found).to eq(true), "IPv6 address #{ip_with_prefix} not found in spec.json networks for instance #{index}"
      end
    end

    it 'creates a deployment with 2 instances and verifies inter-instance IPv6 prefix connectivity', ssh: true do
      instances_prefix_ips = get_ipv6_prefix_addresses

      expect(instances_prefix_ips.keys.length).to be >= 2
      instances_prefix_ips.each do |instance, ip_with_prefix|
        expect(ip_with_prefix).not_to be_nil, "Instance #{instance} does not have an IPv6 address with prefix"
      end

      # Transform the prefix IPs to an actual IPv6 addresses
      instances_usable_ips = {}
      instances_prefix_ips.each do |instance, ip_with_prefix|
        prefix_ip = ip_with_prefix.split('/')[0].chomp('::')
        usable_ip = "#{prefix_ip}::20"
        instances_usable_ips[instance] = usable_ip
      end

      # Configure each instance with its IPv6 address
      instances_usable_ips.each do |instance, usable_ip|
        instance_name, instance_id = instance.split('/')
        config_cmd = <<~SCRIPT
          echo "[Address]" | sudo tee -a /etc/systemd/network/10_eth0.network
          echo "Address=#{usable_ip}" | sudo tee -a /etc/systemd/network/10_eth0.network
          sudo /var/vcap/bosh/bin/restart_networking
        SCRIPT
        bosh_ssh(instance_name, instance_id, config_cmd, deployment: @prefix_deployment.name)
      end

      # Test inter-instance connectivity - each instance pings the other
      instances_usable_ips.each do |source_instance, source_ip|
        source_name, source_id = source_instance.split('/')

        instances_usable_ips.each do |target_instance, target_ip|
          next if source_instance == target_instance  # Skip pinging self

          ping_result = bosh_ssh(source_name, source_id, "ping6 -c 5 #{target_ip}", deployment: @prefix_deployment.name).output
          success = ping_result.match(/0% packet loss/) || ping_result.match(/\d+ packets transmitted, \d+ received/)
          expect(success).to be_truthy, "Ping6 from instance #{source_instance} to #{target_instance} (#{target_ip}) failed: #{ping_result}"
        end
      end
    end
  end
end
