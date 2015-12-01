require 'system/spec_helper'

describe 'raw_instance_storage', core: true do
  before(:all) do
    @requirements.requirement(@requirements.release)
    @requirements.requirement(@requirements.stemcell)
    load_deployment_spec
  end

  after(:all) do
    @requirements.cleanup(deployment)
  end

  before do
    skip 'raw_instance_storage cloud property not supported on this IaaS' unless @requirements.stemcell.supports_raw_ephemeral_storage?

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
    expect(labeled_partitions(public_ip)).to eq(["raw-ephemeral-0"])
  end

  def labeled_partitions(ip)
    output = ssh(ip, 'vcap', 'ls /dev/disk/by-partlabel', @our_ssh_options)
    output.lines.map { |line| line.chomp }
  end
end
