require 'system/spec_helper'
require 'json'
require 'ipaddr'

describe 'IPv6 network configuration', multiple_manual_networks: true, ipv6: true do
  before(:all) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
  end

  context 'when using manual networking and ipv6', ipv6_manual_networking: true do
    before(:all) do
      load_deployment_spec
      use_ipv6
      use_nic_groups
      use_static_ip
      use_multiple_manual_networks
      @deployment = with_deployment
      @requirements.update_cloud_config(@spec)
      expect(bosh("-d #{@deployment.name} deploy #{@deployment.to_path}")).to succeed
    end

    after(:all) do
      @requirements.cleanup(@deployment)
    end

    it 'supports manual network dual stack', dual_stack: true, ssh: true do
      instance_ips = get_instance_ips
      expect(instance_ips.values.first.length).to be > 1

      interfaces = bosh_ssh('batlight', 0, 'ip -o addr', deployment: @deployment.name, result: true,
                                                         column: 'stdout').output

      @spec['properties']['job_networks'].select { |n| n['static_ip'] }.each do |network|
        expect(interfaces).to include(network['static_ip'])
      end
    end
  end

  context 'when allocating IPv6 prefix', ipv6_prefix_allocation: true do
    before(:all) do
      load_deployment_spec
      use_ipv6_network_prefixes
      use_ipv6
      use_nic_groups
      no_static_ip
      use_multiple_manual_networks
      use_instance_count(2)

      @deployment = with_deployment
      @requirements.update_cloud_config(@spec)
      expect(bosh("-d #{@deployment.name} deploy #{@deployment.to_path}")).to succeed
    end

    after(:all) do
      @requirements.cleanup(@deployment)
    end

    it 'verifies the IPv6 prefix in spec.json', ssh: true do
      instances_prefix_ips = get_ipv6_prefix_addresses
      expect(instances_prefix_ips).not_to be_nil

      # Verify each instance's spec.json contains its assigned prefix
      instances_prefix_ips.each_with_index do |(instance, ip_with_prefix), index|
        ip, prefix = ip_with_prefix.split('/')
        instance_name, instance_id = instance.split('/')
        cli_cmd = 'sudo cat /var/vcap/bosh/spec.json'
        spec_output = bosh_ssh(instance_name, instance_id, cli_cmd, deployment: @deployment.name, result: true,
                                                                    column: 'stdout').output
        spec = parse_json_safely(spec_output)

        found = spec['networks'].values.any? do |net|
          IPAddr.new(net['ip']) == IPAddr.new(ip) && net['prefix'].to_s == prefix.to_s
        end

        expect(found).to eq(true),
                         "IPv6 address #{ip_with_prefix} not found in spec.json networks for instance #{index}"
      end
    end

    it 'creates a deployment with 2 instances and verifies inter-instance IPv6 prefix connectivity', ssh: true do
      instances_prefix_ips = get_ipv6_prefix_addresses
      expect(instances_prefix_ips).not_to be_nil, 'Expected instances to have IPv6 prefix addresses but received nil'
      expect(instances_prefix_ips.keys.length).to be >= 2

      instances_prefix_ips.each do |instance, ip_with_prefix|
        expect(ip_with_prefix).not_to be_nil, "Instance #{instance} does not have an IPv6 address with prefix"
      end

      instances_usable_ips = {}
      instances_prefix_ips.each do |instance, ip_with_prefix|
        prefix_ip, prefix_len = ip_with_prefix.split('/')
        # Use a random address within the allocated prefix for testing connectivity
        usable_ip = "#{prefix_ip.chomp('::')}::20"
        usable_ip_with_prefix = "#{usable_ip}/#{prefix_len}"
        instances_usable_ips[instance] = { usable_ip: usable_ip, usable_ip_with_prefix: usable_ip_with_prefix }
      end

      instances_usable_ips.each do |instance, data|
        usable_ip = data[:usable_ip]
        usable_ip_with_prefix = data[:usable_ip_with_prefix]

        instance_name, instance_id = instance.split('/')
          # Grab the interface associated by the IaaS with the prefix from the kernel routes
          probe_cmd = "ip -j -6 route get #{usable_ip}"
          probe_output = bosh_ssh(instance_name, instance_id, probe_cmd, deployment: @deployment.name,
                                                                         result: true, column: 'stdout').output
          # ip -j returns JSON like: [{"dst":"...","from":"::","dev":"eth1",...}]
          parsed = parse_json_safely(probe_output)
          interface = parsed[0]['dev'] if parsed && parsed[0] && parsed[0]['dev']
          if interface.nil? || interface.to_s.empty?
            raise "Failed to determine interface from 'ip -j -6 route get' output on instance #{instance}: #{probe_output.inspect}"
          end

        config_cmd = <<~SCRIPT
          echo "[Address]" | sudo tee -a /etc/systemd/network/10_#{interface}.network
          echo "Address=#{usable_ip_with_prefix}" | sudo tee -a /etc/systemd/network/10_#{interface}.network
          sudo /var/vcap/bosh/bin/restart_networking
        SCRIPT
        bosh_ssh(instance_name, instance_id, config_cmd, deployment: @deployment.name)
      end

      # Test inter-instance connectivity - each instance pings the other
      instances_usable_ips.each_key do |source_instance|
        source_name, source_id = source_instance.split('/')

        instances_usable_ips.each do |target_instance, data|
          next if source_instance == target_instance # Skip pinging self

          ping_result = bosh_ssh(source_name, source_id, "ping6 -c 5 #{data[:usable_ip]}",
                                 deployment: @deployment.name, result: true, column: 'stdout').output
          success = ping_result.match(/0% packet loss/) || ping_result.match(/\d+ packets transmitted, \d+ received/)
          expect(success).to be_truthy,
                             "Ping6 from instance #{source_instance} to #{target_instance} (#{data[:usable_ip_with_prefix]}) failed: #{ping_result}"
        end
      end
    end
  end
end
