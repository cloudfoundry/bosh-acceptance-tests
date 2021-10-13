require 'system/spec_helper'

describe 'persistent disks', core: true do
  before(:all) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
  end

  before(:each) do
    load_deployment_spec
    use_static_ip
    use_vip
  end

  after(:each) do
    @requirements.cleanup(deployment)
  end

  context 'with multiple disks' do
    disk1_size_mb = 5 * 1024
    disk2_size_mb = 4 * 1024

    before(:each) do
      use_multiple_persistent_disks(disk1_size_mb, disk2_size_mb)
      @requirements.requirement(deployment, @spec)
    end

    it 'attaches multiple disks' do
      disk1_bytes = disk1_size_mb * 1024 * 1024
      disk2_bytes = disk2_size_mb * 1024 * 1024

      output = bosh_ssh('batlight', 0, "lsblk -b", deployment: deployment.name).output

      expect(output).to include(disk1_bytes.to_s)
      expect(output).to include(disk2_bytes.to_s)
    end
  end

  context 'with an orphaned disk' do
    before do
      use_persistent_disk(1024)
      @requirements.requirement(deployment, @spec)

      result = bosh("instances --details")
      instance_hash = JSON.parse(result.output)['Tables'][0]['Rows'][0]
      @saved_disk_cid = instance_hash['disk_cids']

      @requirements.cleanup(deployment)
      @requirements.requirement(deployment, @spec)
    end

    it 'can attach the disk to a stopped instance' do
      result = bosh("instances --details")
      instance_hash = JSON.parse(result.output)['Tables'][0]['Rows'][0]
      instance = instance_hash['instance']

      expect(bosh("stop #{instance}", deployment: deployment.name)).to succeed
      expect(bosh("attach-disk #{instance} \"#{@saved_disk_cid}\"", deployment: deployment.name)).to succeed

      result = bosh("instances --details")
      instance_hash = JSON.parse(result.output)['Tables'][0]['Rows'][0]
      expect(instance_hash['disk_cids']).to eq(@saved_disk_cid)
    end
  end
end
