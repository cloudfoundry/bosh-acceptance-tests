require 'system/spec_helper'

describe 'auditd, sshd, cron, rsyslogd', os: true do
  before(:each) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
    load_deployment_spec
    @requirements.requirement(deployment, @spec)
  end

  after(:each) do
    @requirements.cleanup(deployment)
  end

  it 'should be running' do
    output = bosh_ssh('batlight', 0, 'ps ax -o ucmd', deployment: deployment.name).output
    running_services = output.split("\r\n").uniq

    expect(running_services).to include(/ cron$/)
    expect(running_services).to include(/ kauditd$/)
    expect(running_services).to include(/ auditd$/)
    expect(running_services).to include(/ rsyslogd$/)
  end
end
