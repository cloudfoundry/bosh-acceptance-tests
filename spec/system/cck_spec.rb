require 'system/spec_helper'

describe 'cck' do
  before(:all) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
    load_deployment_spec
    @requirements.requirement(deployment, @spec)
    bosh('update-resurrection off')
  end

  after(:all) do
    @requirements.cleanup(deployment)
    bosh('update-resurrection on')
  end

  context 'unresponsive agent' do

    let(:instance_name) { 'batlight' }
    let(:instance_id) { '0' }
    let(:srv_cmd) { service_command(instance_name, instance_id, deployment.name)}

    before do
      @requirements.requirement(deployment, @spec, force: true, bosh_options: '--recreate')
      # stop agent would be bosh-agent. unless we change this in systemd
      bosh_ssh(instance_name, instance_id, "sudo #{srv_cmd} stop agent", deployment: deployment.name)
      @initial_vm_cid = unresponsive_agent_vm_cid
    end

    context 'recreate_vm' do
      it 'should replace vm and keep the persistent disks' do
        initial_disk_cids = get_disk_cids(instance_name, instance_id)
        bosh('-d bat cck --resolution recreate_vm')
        wait_for_process_state(instance_name, instance_id, 'running')
        expect(get_vm_cid(instance_name, instance_id)).not_to eq(@initial_vm_cid)
        expect(get_disk_cids(instance_name, instance_id)).to eq(initial_disk_cids)
      end
    end

    context 'recreate_vm_without_wait' do
      it 'should replace vm' do
        bosh('-d bat cck --resolution recreate_vm_without_wait')
        wait_for_process_state(instance_name, instance_id, 'running')
        expect(get_vm_cid(instance_name, instance_id)).not_to eq(@initial_vm_cid)
      end
    end

    context 'reboot_vm', reboot: true do # --tag ~reboot on warden and AWS
      it 'should reboot vm' do
        bosh('-d bat cck --resolution reboot_vm')
        wait_for_process_state(instance_name, instance_id, 'running')
        expect(get_vm_cid(instance_name, instance_id)).to eq(@initial_vm_cid)
      end
    end

    context 'delete_vm' do
      it 'should delete vm' do
        bosh('-d bat cck --resolution delete_vm')
        wait_for_process_state(instance_name, instance_id, '')
        expect(vm_exists?(@initial_vm_cid)).not_to be_truthy
      end
    end

    context 'delete_vm_reference' do
      it 'should delete vm reference' do
        bosh('-d bat cck --resolution delete_vm_reference')
        wait_for_process_state(instance_name, instance_id, '')
        expect(get_vm_cid(instance_name, instance_id)).to be_empty
      end

      after do
        bosh("-d bat delete-vm '#{@initial_vm_cid}'")
      end
    end
  end
end
