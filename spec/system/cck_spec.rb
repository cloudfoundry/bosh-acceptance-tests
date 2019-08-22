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

    before do |example|
      unless example.metadata[:skip_before]
        bosh_ssh(instance_name, instance_id, 'sudo sv stop agent', deployment: deployment.name)
        @initial_vm_cid = unresponsive_agent_vm_cid
      end
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
        expect(get_instance(instance_name, instance_id)['process_state']).to eq('running')
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

    context 'delete_vm_reference', skip_before: true do
      it 'should delete vm reference' do
        @requirements.requirement(deployment, @spec, force: true, bosh_options: '--recreate')

        @initial_vm_cid = get_vm_cid(instance_name, instance_id)
        bosh_ssh(instance_name, instance_id, 'sudo sv stop agent', deployment: deployment.name)

        bosh('-d bat cck --resolution delete_vm_reference')
        wait_for_process_state(instance_name, instance_id, '')
        expect(get_vm_cid(instance_name, instance_id)).to be_empty
      end

      after do
        bosh("-d bat delete-vm #{@initial_vm_cid}")
      end
    end
  end
end
