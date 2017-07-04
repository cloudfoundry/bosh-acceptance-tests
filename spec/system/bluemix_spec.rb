require 'system/spec_helper'

describe 'check vcap password correct' do
  before(:all) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
    load_deployment_spec
    @requirements.requirement(deployment, @spec)
  end

  after(:all) do
    @requirements.cleanup(deployment)
  end

  it 'vcap should exist in shadow and user_data.json' do
    passwd = '$6$3n/Y5RP0$Jr1nLxatojY9Wlqduzwh66w8KmYxjoj9vzI62n3Mmstd5mNVnm0SS1N0YizKOTlJCY5R/DFmeWgbkrqHIMGd51'
    output_shadow = bosh_ssh('batlight', 0, "sudo cat /etc/shadow").output
    #running_services_shadow = output_shadow.split("\n").uniq
    expect(output_shadow).to include(passwd)

    output_json = bosh_ssh('batlight', 0, "sudo cat /var/vcap/bosh/user_data.json").output
    #running_services_json = output_json.split("\n").uniq
    expect(output_json).to include(passwd)
  end
end
