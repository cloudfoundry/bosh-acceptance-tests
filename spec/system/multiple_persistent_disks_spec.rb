require 'system/spec_helper'

fdescribe 'with multiple persistent disks', core: true do
  disk1_size = 1337
  disk2_size = 404

  before(:all) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
  end

  before(:all) do
    load_deployment_spec
    use_static_ip
    use_vip
    use_multiple_persistent_disks(disk1_size, disk2_size)
    @requirements.requirement(deployment, @spec) # 2.5 min on local vsphere
  end

  after(:all) do
    @requirements.cleanup(deployment)
  end

  it 'attaches multiple disks' do
    disk1_bytes = disk1_size * 1024
    disk2_bytes = disk2_size * 1024

    output = bosh_ssh('batlight', 0, "lsblk -b", deployment: deployment.name).output

    expect(output).to include(disk1_bytes)
    expect(output).to include(disk2_bytes)
  end
end
