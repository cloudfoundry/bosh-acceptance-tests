require 'system/spec_helper'

describe 'check vcap password correct 222' do
  before(:all) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
    load_deployment_spec
    @requirements.requirement(deployment, @spec)
  end

  after(:all) do
    @requirements.cleanup(deployment)
  end

  fit 'vcap should exist in shadow and user_data.json' do
    passwd = '$6$3n/Y5RP0$Jr1nLxatojY9Wlqduzwh66w8KmYxjoj9vzI62n3Mmstd5mNVnm0SS1N0YizKOTlJCY5R/DFmeWgbkrqHIMGd51'
    output_shadow = bosh_ssh('batlight', 0, "sudo sh -c \"cat /etc/shadow | grep #{passwd}\"").output
    running_services_shadow = output_shadow.split("\n").uniq
    expect(running_services_shadow).to include(passwd)

    output_json = bosh_ssh('batlight', 0, "sudo sh -c \"cat /var/vcap/bosh/user_data.json | grep #{passwd}\"").output
    running_services_json = output_json.split("\n").uniq
    expect(running_services_json).to include(passwd)
  end
end
