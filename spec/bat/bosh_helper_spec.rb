require 'spec_helper'
require 'bat/env'
require 'bat/bosh_runner'
require 'bat/bosh_helper'

describe Bat::BoshHelper do
  subject(:bosh_helper) { Class.new { include Bat::BoshHelper }.new }

  let(:bosh_runner) { instance_double('Bat::BoshRunner') }

  before do
    bosh_helper.instance_variable_set('@bosh_runner', bosh_runner)
    stub_const('ENV', {})
    bosh_helper.instance_variable_set('@logger', Logger.new('/dev/null'))
  end

  describe '#ssh_options' do
    let(:env) { instance_double('Bat::Env') }
    before do
      bosh_helper.instance_variable_set('@env', env)
      allow(env).to receive(:private_key).and_return('fake_private_key')
    end

    it 'returns the private key from the env' do
      expect(bosh_helper.ssh_options).to eq(private_key: 'fake_private_key')
    end
  end

  describe 'persistent_disk' do
    let(:job_name) { 'some-job' }
    let(:job_index) { 'some-index' }
    let(:ssh_command) { "ssh #{job_name}/#{job_index} -c 'df -x tmpfs -x devtmpfs -x debugfs -l | tail -n +2' --results --column=stdout" }

    before do
      allow(bosh_runner).to receive(:bosh).with(ssh_command, { json: false })
        .and_return(ssh_output)
      allow(bosh_runner).to receive(:bosh).with('tasks --recent')
        .and_return('{ "Tables": [{ "Rows": [] }] }')
    end

    context 'when a persistent disk is present' do
      let(:df_output) do
        %q(
/dev/fake       3000 2000  1000   66% /var/vcap/store
/dev/fake-ephemeral       3000 2000  1000   66% /var/vcap/data
)
      end
      let(:ssh_output) { Bosh::Exec::Result.new(ssh_command, df_output, 0) }

      it 'returns the size of the persistent disk' do
        expect(bosh_helper.persistent_disk(job_name, job_index, {})).to eq('3000')
      end
    end

    context 'when a persistent disk is not found' do
      let(:ssh_output) { Bosh::Exec::Result.new(ssh_command, '/dev/fake-ephemeral       3000 2000  1000   66% /var/vcap/data' , 0) }

      it 'raises error' do
        expect {
          bosh_helper.persistent_disk(job_name, job_index, {})
        }.to raise_error(RuntimeError, 'Could not find persistent disk size')
      end
    end
  end

  describe '#wait_for_instance_state' do
    # rubocop:disable LineLength
    let(:bosh_instances_output_with_jesse_in_running_state) { <<-'OUTPUT' }
{
    "Tables": [
        {
            "Content": "instances",
            "Header": {
                "instance":           "Instance",
                "process_state":      "Process State",
                "az":                 "AZ",
                "ips":                "IPs",
                "state":              "State",
                "vm_cid":             "VM CID",
                "vm_type":            "VM Type",
                "disk_cids":          "Disk CIDs",
                "agent_id":           "Agent ID",
                "index":              "Index",
                "resurrection_paused":"Resurrection\nPaused",
                "bootstrap":          "Bootstrap",
                "ignore":             "Ignore"
            },
            "Rows": [
                {
                  "instance":             "jessez/29ae97ec-3106-450b-a848-98cb3b25d86f",
                  "process_state":        "running",
                  "az":                   "z3",
                  "ips":                  "10.20.30.1",
                  "state":                "started",
                  "vm_cid":               "i-cid",
                  "vm_type":              "default",
                  "disk_cids":            "daafa7a0-1df2-4482-67e4-6ec795c76434",
                  "agent_id":             "fake-agent-id",
                  "index":                "0",
                  "resurrection_paused":  "false",
                  "bootstrap":            "false",
                  "ignore":               "false"
                },
                {
                 "instance":              "uaa_z1/a3cebb2f-2553-46e3-aa0d-d2075cd08760",
                 "process_state":         "running",
                 "az":                    "z1",
                 "ips":                   "10.50.91.2",
                 "state":                 "started",
                 "vm_cid":                "i-24cb6153",
                 "vm_type":               "default",
                 "disk_cids":             "df5de774-8a0c-4e4c-7418-93e425de3aa2",
                 "agent_id":              "da74e0d8-d2a6-4b2d-904a-b2f0e3dacc49",
                 "index":                 "0",
                 "resurrection_paused":   "false",
                 "bootstrap":             "false",
                 "ignore":                "false"
                }
            ],
            "Notes": null
        }
    ],
    "Blocks": null,
    "Lines": [
        "Using environment '0.0.0.0' as client 'admin'",
        "Task 4",
        ". Done",
        "Succeeded"
    ]
}
OUTPUT

    let(:bosh_instances_output_with_jesse_in_unresponsive_state) { <<'OUTPUT' }
{
    "Tables": [
        {
            "Content": "instances",
            "Header": {
                "instance":           "Instance",
                "process_state":      "Process State",
                "az":                 "AZ",
                "ips":                "IPs",
                "state":              "State",
                "vm_cid":             "VM CID",
                "vm_type":            "VM Type",
                "disk_cids":          "Disk CIDs",
                "agent_id":           "Agent ID",
                "index":              "Index",
                "resurrection_paused": "Resurrection\nPaused",
                "bootstrap":          "Bootstrap",
                "ignore":             "Ignore"
            },
            "Rows": [
                {
                   "instance":            "jessez/29ae97ec-3106-450b-a848-98cb3b25d86f",
                   "process_state":       "unresponsive agent",
                   "az":                  "z3",
                   "ips":                 "10.20.30.1",
                   "state":               "started",
                   "vm_cid":              "i-cid",
                   "vm_type":             "default",
                   "disk_cids":           "daafa7a0-1df2-4482-67e4-6ec795c76434",
                   "agent_id":            "fake-agent-id",
                   "index":               "0",
                   "resurrection_paused": "false",
                   "bootstrap":           "false",
                   "ignore":              "false"
                },
                {
                  "instance":             "uaa_z1/a3cebb2f-2553-46e3-aa0d-d2075cd08760",
                  "process_state":        "running",
                  "az":                   "z1",
                  "ips":                  "10.50.91.2",
                  "state":                "started",
                  "vm_cid":               "i-24cb6153",
                  "vm_type":              "default",
                  "disk_cids":            "df5de774-8a0c-4e4c-7418-93e425de3aa2",
                  "agent_id":             "da74e0d8-d2a6-4b2d-904a-b2f0e3dacc49",
                  "index":                "0",
                  "resurrection_paused":  "false",
                  "bootstrap":            "false",
                  "ignore":               "false"
                }
            ],
            "Notes": null
        }
    ],
    "Blocks": null,
    "Lines": [
        "Using environment '0.0.0.0' as client 'admin'",
        "Task 4",
        ". Done",
        "Succeeded"
    ]
}
OUTPUT
    let(:bosh_instances_output_without_jesse) { <<'OUTPUT' }
{
    "Tables": [
        {
            "Content": "instances",
            "Header": {
                "instance":            "Instance",
                "process_state":       "Process State",
                "az":                  "AZ",
                "ips":                 "IPs",
                "state":               "State",
                "vm_cid":              "VM CID",
                "vm_type":             "VM Type",
                "disk_cids":           "Disk CIDs",
                "agent_id":            "Agent ID",
                "index":               "Index",
                "resurrection_paused": "Resurrection\nPaused",
                "bootstrap":           "Bootstrap",
                "ignore":              "Ignore"
            },
            "Rows": [
                {
                 "instance":              "uaa_z1/a3cebb2f-2553-46e3-aa0d-d2075cd08760",
                 "process_state":         "running",
                 "az":                    "z1",
                 "ips":                   "10.50.91.2",
                 "state":                 "started",
                 "vm_cid":                "i-24cb6153",
                 "vm_type":               "default",
                 "disk_cids":             "df5de774-8a0c-4e4c-7418-93e425de3aa2",
                 "agent_id":              "da74e0d8-d2a6-4b2d-904a-b2f0e3dacc49",
                 "index":                 "0",
                 "resurrection_paused":   "false",
                 "bootstrap":             "false",
                 "ignore":                "false"
                }
            ],
            "Notes": null
        }
    ],
    "Blocks": null,
    "Lines": [
        "Using environment '0.0.0.0' as client 'admin'",
        "Task 4",
        ". Done",
        "Succeeded"
    ]
}
OUTPUT
      # rubocop:enable LineLength
    context 'when "instance" in expected state' do
      before do
        fake_result = double('fake bosh exec result', output: bosh_instances_output_with_jesse_in_running_state)
        allow(bosh_runner).to receive(:bosh).with('instances --details').and_return(fake_result)
      end

      it 'returns the instance details' do
        expect(bosh_helper.wait_for_instance_state('jessez', '0', 'running', 0)).to(eq(
          'instance' => 'jessez/29ae97ec-3106-450b-a848-98cb3b25d86f',
          'process_state' => 'running',
          'ips' => '10.20.30.1',
          'vm_cid' => 'i-cid',
          'vm_type' => 'default',
          'ignore' => 'false',
          'agent_id' => 'fake-agent-id',
          'resurrection_paused' => 'false',
          'az' => 'z3',
          'bootstrap' => 'false',
          'disk_cids' => 'daafa7a0-1df2-4482-67e4-6ec795c76434',
          'index' => '0',
          'state' => 'started',
        ))
      end

      context 'when the director is using legacy instance names' do
    let(:bosh_instances_output_with_jesse_in_running_state) { <<'OUTPUT' }
{
    "Tables": [
        {
            "Content": "instances",
            "Header": {
                "instance":           "Instance",
                "process_state":      "Process State",
                "az":                 "AZ",
                "ips":                "IPs",
                "state":              "State",
                "vm_cid":             "VM CID",
                "vm_type":            "VM Type",
                "disk_cids":          "Disk CIDs",
                "agent_id":           "Agent ID",
                "index":              "Index",
                "resurrection_paused":"Resurrection\nPaused",
                "bootstrap":          "Bootstrap",
                "ignore":             "Ignore"
            },
            "Rows": [
                {
                 "instance":              "jessez/0 (29ae97ec-3106-450b-a848-98cb3b25d86f)",
                 "process_state":         "running",
                 "az":                    "z3",
                 "ips":                   "10.20.30.1",
                 "state":                 "started",
                 "vm_cid":                "i-cid",
                 "vm_type":               "default",
                 "disk_cids":             "daafa7a0-1df2-4482-67e4-6ec795c76434",
                 "agent_id":              "fake-agent-id",
                 "index":                 "0",
                 "resurrection_paused":   "false",
                 "bootstrap":             "false",
                 "ignore":                "false"
                },
                {
                  "instance":             "uaa_z1/0 (a3cebb2f-2553-46e3-aa0d-d2075cd08760)",
                  "process_state":        "running",
                  "az":                   "z1",
                  "ips":                  "10.50.91.2",
                  "state":                "started",
                  "vm_cid":               "i-24cb6153",
                  "vm_type":              "default",
                  "disk_cids":            "df5de774-8a0c-4e4c-7418-93e425de3aa2",
                  "agent_id":             "da74e0d8-d2a6-4b2d-904a-b2f0e3dacc49",
                  "index":                "0",
                  "resurrection_paused":  "false",
                  "bootstrap":            "false",
                  "ignore":               "false"
                }
            ],
            "Notes": null
        }
    ],
    "Blocks": null,
    "Lines": [
        "Using environment '0.0.0.0' as client 'admin'",
        "Task 4",
        ". Done",
        "Succeeded"
    ]
}
OUTPUT

        it 'returns the instance details' do
          expect(bosh_helper.wait_for_instance_state('jessez', '0', 'running', 0)).to(eq(
            'instance' => 'jessez/0 (29ae97ec-3106-450b-a848-98cb3b25d86f)',
            'process_state' => 'running',
            'ips' => '10.20.30.1',
            'vm_cid' => 'i-cid',
            'vm_type' => 'default',
            'ignore' => 'false',
            'agent_id' => 'fake-agent-id',
            'resurrection_paused' => 'false',
            'az' => 'z3',
            'bootstrap' => 'false',
            'disk_cids' => 'daafa7a0-1df2-4482-67e4-6ec795c76434',
            'index' => '0',
            'state' => 'started',
          ))
        end
      end
    end

    context 'when "instance" in different state' do
      before do
        fake_result = double('fake bosh exec result', output: bosh_instances_output_with_jesse_in_unresponsive_state)
        allow(bosh_runner).to receive(:bosh).with('instances --details').and_return(fake_result)
      end

      it 'returns nil' do
        expect{bosh_helper.wait_for_instance_state('jessez', '0', 'running', 0)}.to raise_error
      end
    end

    context 'when "instance" is missing in "bosh instances" output' do
      before do
        fake_result = double('fake bosh exec result', output: bosh_instances_output_without_jesse)
        allow(bosh_runner).to receive(:bosh).with('instances --details').and_return(fake_result)
      end

      it 'returns nil' do
        expect{bosh_helper.wait_for_instance_state('jessez', '0', 'running', 0)}.to raise_error
      end
    end

    context 'when "instance" was not in desired state at first, but appear after 4 retries' do
      let(:bad_result) { double('fake exec result', output: bosh_instances_output_with_jesse_in_unresponsive_state) }
      let(:good_result) { double('fake good exec result', output: bosh_instances_output_with_jesse_in_running_state) }
      before do
        allow(bosh_runner).to receive(:bosh).with('instances --details').and_return(
            bad_result,
            bad_result,
            bad_result,
            good_result,
        )
      end

      it 'returns the instance details' do
        expect(bosh_helper.wait_for_instance_state('jessez', '0', 'running', 0)).to(eq(
          'instance' => 'jessez/29ae97ec-3106-450b-a848-98cb3b25d86f',
          'process_state' => 'running',
          'ips' => '10.20.30.1',
          'vm_cid' => 'i-cid',
          'vm_type' => 'default',
          'ignore' => 'false',
          'agent_id' => 'fake-agent-id',
          'resurrection_paused' => 'false',
          'az' => 'z3',
          'bootstrap' => 'false',
          'disk_cids' => 'daafa7a0-1df2-4482-67e4-6ec795c76434',
          'index' => '0',
          'state' => 'started',
        ))
      end
    end
  end
end
