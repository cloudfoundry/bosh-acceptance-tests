require 'system/spec_helper'

xdescribe 'with multiple persistent disks', core: true do
  disk1_size_mb = 5 * 1024
  disk2_size_mb = 4 * 1024

  before(:all) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
  end

  before(:each) do
    load_deployment_spec
    use_static_ip
    use_vip
    use_multiple_persistent_disks(disk1_size_mb, disk2_size_mb)
    @requirements.requirement(deployment, @spec) # 2.5 min on local vsphere
  end

  after(:all) do
    @requirements.cleanup(deployment)
  end

  it 'attaches multiple disks' do
    disk1_bytes = disk1_size_mb * 1024 * 1024
    disk2_bytes = disk2_size_mb * 1024 * 1024

    output = bosh_ssh('batlight', 0, "lsblk -b", deployment: deployment.name).output

    expect(output).to include(disk1_bytes.to_s)
    expect(output).to include(disk2_bytes.to_s)
  end

  context 'orphaning a disk and mounting a new disk' do
    let(:single_disk_deploy) {
      use_persistent_disk(1024)
      with_deployment
    }

    before do
      expect(bosh("deploy #{single_disk_deploy.to_path}", deployment: single_disk_deploy.name)).to succeed
    end

    after do
      single_disk_deploy.delete
    end

    it 'cli can attach a disk' do
      result = bosh('disks --orphaned', deployment: single_disk_deploy.name)
      orphaned_disks = JSON.parse(result.output)['Tables'][0]['Rows']
      instance_id = orphaned_disks[0]['instance']
      volume_id = orphaned_disks[0]['disk_cid']

      old_size = persistent_disk('batlight', 0, deployment: single_disk_deploy.name)

      bosh("stop #{instance_id}", deployment: single_disk_deploy.name)
      bosh("attach-disk #{instance_id} #{volume_id}", deployment: single_disk_deploy.name)

      new_size = persistent_disk("batlight", 0, deployment: single_disk_deploy.name)
      expect(new_size).to_not(eq(old_size))
    end
  end
end
