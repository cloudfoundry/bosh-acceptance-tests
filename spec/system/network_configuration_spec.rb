require 'system/spec_helper'
require 'set'

describe 'network configuration' do
  before(:all) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
    load_deployment_spec
  end

  context 'when using manual networking', manual_networking: true do
    before(:all) do
      use_static_ip
      use_vip
      @deployment = with_deployment
      expect(bosh("-d #{@deployment.name} deploy #{@deployment.to_path}")).to succeed
    end

    after(:all) do
      @requirements.cleanup(@deployment)
    end

    it 'changes static IP address', changing_static_ip: true, ssh: true do
      use_second_static_ip
      deployment = with_deployment
      expect(bosh("-d #{deployment.name} deploy #{deployment.to_path}")).to succeed

      expect(bosh_ssh('batlight', 0, 'ip -o addr', deployment: deployment.name, result: true,
                                                   column: 'stdout').output).to include(second_static_ip)
    end

    it 'deploys multiple manual networks', multiple_manual_networks: true, ssh: true do
      use_multiple_manual_networks
      deployment = with_deployment
      expect(bosh("-d #{deployment.name} deploy #{deployment.to_path}")).to succeed

      interfaces = bosh_ssh('batlight', 0, 'ip -o addr', deployment: deployment.name, result: true,
                                                         column: 'stdout').output
      expect(get_instance_ips.values.first.length).to be > 1
      static_ips.each do |network|
        expect(interfaces).to include(network)
      end
    end
  end

  context 'when using nic_groups', nic_groups: true, multiple_manual_networks: true do
    before(:all) do
      load_deployment_spec
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

    it 'assigns networks with the same nic_group to the same interface', ssh: true do
      job_networks = @spec['properties']['job_networks']
      networks_with_nic_groups = job_networks.select { |n| n['static_ip'] && n['nic_group'] }

      output = bosh_ssh('batlight', 0, 'ip -j addr', deployment: @deployment.name, result: true,
                                                     column: 'stdout').output
      raw_interfaces_json = parse_json_safely(output)

      ip_to_interface_map = {}
      raw_interfaces_json.reject { |iface| iface['ifname'] == 'lo' }.each do |iface|
        (iface['addr_info'] || []).each do |addr|
          ip_to_interface_map[addr['local']] = iface['ifname']
        end
      end

      # {<nic_group>=>#<Set: {"NICX"}>, <nic_group>=>#<Set: {"NICX"}>}
      nic_group_to_interface_set = Hash.new { |h, k| h[k] = Set.new }
      networks_with_nic_groups.each do |network|
        static_ip = network['static_ip']
        nic_group = network['nic_group']
        interface_name = ip_to_interface_map[static_ip]

        expect(interface_name).not_to be_nil,
                                      "Static IP #{static_ip} from network '#{network['name']}' not found on any interface"
        nic_group_to_interface_set[nic_group] << interface_name
      end

      nic_group_to_interface_set.each do |nic_group, interface_set|
        expect(interface_set.size).to eq(1),
                                      "Networks with nic_group #{nic_group} should be on the same interface, but found on: #{interface_set.to_a.join(', ')}"
      end
    end
  end
end
