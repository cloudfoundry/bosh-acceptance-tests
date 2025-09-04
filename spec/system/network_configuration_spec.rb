require 'system/spec_helper'
require 'set'

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
    it 'deploys multiple manual networks', multiple_manual_networks: true, ssh: true do
      use_multiple_manual_networks
      deployment = with_deployment
      expect(bosh("-d #{deployment.name} deploy #{deployment.to_path}")).to succeed

      expect(bosh_ssh('batlight', 0, 'PATH=/sbin:/usr/sbin:$PATH; ifconfig',
                      deployment: deployment.name).output).to include(static_ips[0])
      expect(bosh_ssh('batlight', 0, 'PATH=/sbin:/usr/sbin:$PATH; ifconfig',
                      deployment: deployment.name).output).to include(static_ips[1])
    end

    it 'changes static IP address', changing_static_ip: true, ssh: true do
      use_second_static_ip
      deployment = with_deployment
      expect(bosh("-d #{deployment.name} deploy #{deployment.to_path}")).to succeed

      expect(bosh_ssh('batlight', 0, 'PATH=/sbin:/usr/sbin:$PATH; ifconfig',
                      deployment: deployment.name).output).to include(second_static_ip)
    end
  end

  context 'when using nic_groups', nic_groups: true do
    before(:all) do
      use_multiple_manual_networks
      skip "Skipping nic_groups tests because a nic_group is not defined" if nic_groups.empty?
    end
    it 'assigns networks with the same nic_group to the same interface', ssh: true do
      job_networks = @spec['properties']['job_networks']
      networks_with_nic_groups = job_networks.select { |n| n['static_ip'] && n['nic_group'] }

      deployment = with_deployment
      expect(bosh("-d #{deployment.name} deploy #{deployment.to_path}")).to succeed

      cli_cmd = 'output_data=$(ip -j addr); echo "----$output_data----"'
      output = bosh_ssh('batlight', 0, cli_cmd, deployment: deployment.name).output
      raw_interfaces_json = JSON.parse(extract_ssh_stdout_between_dashes(output))

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
