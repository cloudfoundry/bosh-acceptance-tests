require 'system/spec_helper'

describe 'cck' do
  before(:all) do
    bosh('update-resurrection off')
  end

  before(:each) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
    load_deployment_spec
    @requirements.requirement(deployment, @spec)
  end

  after(:each) do
    @requirements.cleanup(deployment)
  end

  after(:all) do
    bosh('update-resurrection on')
  end

  # TODO test orphaning with create-swap-delete strategy / enable_virtual_delete?

  context 'unresponsive agent' do
    before do
      bosh_ssh('batlight', 0, 'sudo sv stop agent', deployment: deployment.name)
    end

    context 'recreate_vm' do
      it 'should replace vm' do
        bosh('-d bat cck --resolution recreate_vm')
        wait_for_process_state('batlight', '0', 'running')
        # TODO assert cid change?
      end
    end

    context 'recreate_vm_without_wait' do
      it 'should replace vm' do
        bosh('-d bat cck --resolution recreate_vm_without_wait')
        wait_for_process_state('batlight', '0', 'running')
        # TODO assert cid change?
        # TODO assert processes still starting?
      end
    end

    context 'reboot_vm', reboot: true do # --tag ~reboot on warden
      it 'should reboot vm' do
        bosh('-d bat cck --resolution reboot_vm')
        wait_for_process_state('batlight', '0', 'running')
        # TODO assert cid same?
      end
    end

    context 'delete_vm' do
      it 'should delete vm' do
        bosh('-d bat cck --resolution delete_vm')
        wait_for_instance_state('batlight', '0', 'detached')
        # TODO
      end
    end

    context 'delete_vm_reference' do
      it 'should delete vm reference' do
        bosh('-d bat cck --resolution delete_vm_reference')
        wait_for_instance_state('batlight', '0', 'detached')
        # TODO
      end

      after do
        bosh('clean-up --all') # delete orphaned VM
      end
    end
  end

  context 'inactive disk' do

  end

  context 'missing disk' do

  end

  context 'missing vm' do

  end

  context 'mount info mismatch' do

  end
end
