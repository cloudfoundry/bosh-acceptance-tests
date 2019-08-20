require 'system/spec_helper'

describe 'cck' do
  before(:all) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
    load_deployment_spec
    @requirements.requirement(deployment, @spec)
  end

  before(:each) do
    bosh('update-resurrection off')
  end

  after(:each) do
    bosh('update-resurrection on')
  end

  after(:all) do
    @requirements.cleanup(deployment)
  end

  context 'unresponsive agent' do
    let(:instance_name) { 'batlight' }
    let(:instance_id) { '0' }

    before do
      bosh_ssh(instance_name, instance_id, 'sudo sv stop agent', deployment: deployment.name)
    end

    context 'recreate_vm' do
      it 'should replace vm and keep the persistent disks' do
        initial_vm_cid = get_vm_cid(instance_name, instance_id)
        initial_disk_cids = get_disk_cids(instance_name, instance_id)
        bosh('-d bat cck --resolution recreate_vm')
        wait_for_process_state(instance_name, instance_id, 'running')
        expect(get_vm_cid(instance_name, instance_id)).not_to eq(initial_vm_cid)
        expect(get_disk_cids(instance_name, instance_id)).to eq(initial_disk_cids)
      end
    end

    context 'recreate_vm_without_wait' do
      it 'should replace vm' do
        inital_cid = get_vm_cid(instance_name, instance_id)
        bosh('-d bat cck --resolution recreate_vm_without_wait')
        expect(get_instance(instance_name, instance_id)['process_state']).to eq('running')
        wait_for_process_state(instance_name, instance_id, 'running')
        expect(get_vm_cid(instance_name, instance_id)).not_to eq(inital_cid)
      end
    end

    context 'reboot_vm', reboot: true do # --tag ~reboot on warden
      it 'should reboot vm' do
        inital_cid = get_vm_cid(instance_name, instance_id)
        bosh('-d bat cck --resolution reboot_vm')
        wait_for_process_state(instance_name, instance_id, 'running')
        expect(get_vm_cid(instance_name, instance_id)).to eq(inital_cid)
      end
    end

    context 'delete_vm' do
      it 'should delete vm' do
        bosh('-d bat cck --resolution delete_vm')
        wait_for_process_state(instance_name, instance_id, '')
        expect(get_agent_id(instance_name, instance_id)).to be_empty
      end
    end

    context 'delete_vm_reference' do
      let!(:initial_cid) { get_vm_cid(instance_name, instance_id) }

      it 'should delete vm reference' do
        bosh('-d bat cck --resolution delete_vm_reference')
        wait_for_process_state(instance_name, instance_id, '')
        expect(get_vm_cid(instance_name, instance_id)).to be_empty
      end

      after do
        bosh("-d bat delete-vm #{initial_cid}")
      end
    end
  end
end
