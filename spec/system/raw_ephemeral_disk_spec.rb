require 'system/spec_helper'

describe 'raw_instance_storage', raw_ephemeral_storage: true do
  before(:all) do
    @requirements.requirement(@requirements.release)
    @requirements.requirement(@requirements.stemcell)
    load_deployment_spec
  end

  after(:all) do
    @requirements.cleanup(deployment)
  end

  before do
    reload_deployment_spec
    # using password 'foobar'
    use_password('$6$tHAu4zCTso$pAQok0MTHP4newel7KMhTzMI4tQrAWwJ.X./fFAKjbWkCb5sAaavygXAspIGWn8qVD8FeT.Z/XN4dvqKzLHhl0')
    @our_ssh_options = ssh_options.merge(password: 'foobar')
    use_static_ip
    use_vip
    use_job('batlight')
    use_templates(%w[batlight])
    use_raw_instance_storage

    @requirements.requirement(deployment, @spec)
  end

  it 'should attach all available instance disks and label them', ssh: true do
    # assumes aws.yml.erb specifies instance_type: m3.medium, which has 1 local disk
    output = bosh_ssh('batlight', 0, 'ls /dev/disk/by-partlabel', deployment: deployment.name).output
    expect(output).to include('raw-ephemeral-0')
  end
end
