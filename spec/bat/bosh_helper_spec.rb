require 'spec_helper'
require 'bat/env'
require 'bat/bosh_runner'
require 'bat/bosh_helper'

describe Bat::BoshHelper do
  subject(:bosh_helper) do
    Class.new { include Bat::BoshHelper }.new
  end

  before { bosh_helper.instance_variable_set('@bosh_runner', bosh_runner) }
  let(:bosh_runner) { instance_double('Bat::BoshRunner') }

  before { bosh_helper.instance_variable_set('@bosh_runner', bosh_runner) }
  let(:bosh_runner) { instance_double('Bat::BoshRunner') }

  before { stub_const('ENV', {}) }

  before { bosh_helper.instance_variable_set('@logger', Logger.new('/dev/null')) }

  describe '#ssh_options' do
    let(:env) { instance_double('Bat::Env') }
    before { bosh_helper.instance_variable_set('@env', env) }
    before { allow(env).to receive(:vcap_password).and_return('fake_password') }

    context 'when both env var BAT_VCAP_PRIVATE_KEY is set' do
      before { allow(env).to receive(:vcap_private_key).and_return('fake_private_key') }
      it { expect(bosh_helper.ssh_options).to eq(private_key: 'fake_private_key', password: 'fake_password') }
    end

    context 'when BAT_VCAP_PRIVATE_KEY is not set in env' do
      before { allow(env).to receive(:vcap_private_key).and_return(nil) }
      it { expect(bosh_helper.ssh_options).to eq(password: 'fake_password', private_key: nil) }
    end
  end

  describe '#wait_for_vm_state' do
    # rubocop:disable LineLength
    let(:bosh_vms_output_with_jesse_in_running_state) { <<OUTPUT }
Deployment 'jesse'

Director task 1112

Task 5402 done

+-------------------------------------------------+---------+---------------+-------------+------------+--------------------------------------+--------------+
| VM                                              | State   | Resource Pool | IPs         | CID        | Agent ID                             | Resurrection |
+-------------------------------------------------+---------+---------------+-------------+------------+--------------------------------------+--------------+
| jessez/0 (29ae97ec-3106-450b-a848-98cb3b25d86f) | running | fake_pool     | 10.20.30.1  | i-cid      | fake-agent-id                        | active       |
| uaa_z1/0 (a3cebb2f-2553-46e3-aa0d-d2075cd08760) | running | small_z1      | 10.50.91.2  | i-24cb6153 | da74e0d8-d2a6-4b2d-904a-b2f0e3dacc49 | active       |
+-------------------------------------------------+---------+---------------+-------------+------------+--------------------------------------+--------------+

VMs total: 2
OUTPUT
    let(:bosh_vms_output_with_jesse_in_unresponsive_state) { <<OUTPUT }
Deployment 'jesse'

Director task 1112

Task 5402 done

+-------------------------------------------------+---------+---------------+-------------+------------+--------------------------------------+--------------+
| VM                                              | State   | Resource Pool | IPs         | CID        | Agent ID                             | Resurrection |
+-------------------------------------------------+---------+---------------+-------------+------------+--------------------------------------+--------------+
| jessez/0 (29ae97ec-3106-450b-a848-98cb3b25d86f) | unresponsive agent | fake_pool     | 10.20.30.1  | i-cid      | fake-agent-id                        | active       |
| uaa_z1/0 (a3cebb2f-2553-46e3-aa0d-d2075cd08760) | running | small_z1      | 10.50.91.2  | i-24cb6153 | da74e0d8-d2a6-4b2d-904a-b2f0e3dacc49 | active       |
+-------------------------------------------------+---------+---------------+-------------+------------+--------------------------------------+--------------+


VMs total: 2
OUTPUT
    let(:bosh_vms_output_without_jesse) { <<OUTPUT }
Deployment 'jesse'

Director task 1112

Task 5402 done

+-------------------------------------------------+---------+---------------+-------------+------------+--------------------------------------+--------------+
| VM                                              | State   | Resource Pool | IPs         | CID        | Agent ID                             | Resurrection |
+-------------------------------------------------+---------+---------------+-------------+------------+--------------------------------------+--------------+
| uaa_z1/0 (a3cebb2f-2553-46e3-aa0d-d2075cd08760) | running | small_z1      | 10.50.91.2  | i-24cb6153 | da74e0d8-d2a6-4b2d-904a-b2f0e3dacc49 | active       |
+-------------------------------------------------+---------+---------------+-------------+------------+--------------------------------------+--------------+


VMs total: 2
OUTPUT
      # rubocop:enable LineLength
    context 'when "vm" in expected state' do
      before do
        fake_result = double('fake bosh exec result', output: bosh_vms_output_with_jesse_in_running_state)
        allow(bosh_runner).to receive(:bosh).with('vms --details').and_return(fake_result)
      end

      it 'returns the vm details' do
        expect(bosh_helper.wait_for_vm_state('jessez/0', 'running', 0)).to(eq(
          vm: 'jessez/0 (29ae97ec-3106-450b-a848-98cb3b25d86f)',
          state: 'running',
          resource_pool: 'fake_pool',
          ips: '10.20.30.1',
          cid: 'i-cid',
          agent_id: 'fake-agent-id',
          resurrection: 'active',
        ))
      end
    end

    context 'when "vm" in different state' do
      before do
        fake_result = double('fake bosh exec result', output: bosh_vms_output_with_jesse_in_unresponsive_state)
        allow(bosh_runner).to receive(:bosh).with('vms --details').and_return(fake_result)
      end

      it 'returns nil' do
        expect{bosh_helper.wait_for_vm_state('jessez/0', 'running', 0)}.to raise_error
      end
    end

    context 'when "vm" is missing in "bosh vms" output' do
      before do
        fake_result = double('fake bosh exec result', output: bosh_vms_output_without_jesse)
        allow(bosh_runner).to receive(:bosh).with('vms --details').and_return(fake_result)
      end

      it 'returns nil' do
        expect{bosh_helper.wait_for_vm_state('jessez/0', 'running', 0)}.to raise_error
      end
    end

    context 'when "vm" was not in desired state at first, but appear after 4 retries' do
      let(:bad_result) { double('fake exec result', output: bosh_vms_output_with_jesse_in_unresponsive_state) }
      let(:good_result) { double('fake good exec result', output: bosh_vms_output_with_jesse_in_running_state) }
      before do
        allow(bosh_runner).to receive(:bosh).with('vms --details').and_return(
            bad_result,
            bad_result,
            bad_result,
            good_result,
        )
      end

      it 'returns the vm details' do
        expect(bosh_helper.wait_for_vm_state('jessez/0', 'running', 0)).to(eq(
          vm: 'jessez/0 (29ae97ec-3106-450b-a848-98cb3b25d86f)',
          state: 'running',
          resource_pool: 'fake_pool',
          ips: '10.20.30.1',
          cid: 'i-cid',
          agent_id: 'fake-agent-id',
          resurrection: 'active',
        ))
      end
    end
  end
end
