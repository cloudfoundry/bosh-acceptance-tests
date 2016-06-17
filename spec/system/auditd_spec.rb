require 'system/spec_helper'

describe 'auditd, sshd, cron, rsyslogd', system_services_running: true do
  before(:all) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
    load_deployment_spec
    @requirements.requirement(deployment, @spec)
  end

  after(:all) do
    @requirements.cleanup(deployment)
  end

  it 'should be running' do
    output = bosh_ssh('batlight', 0, 'ps aux | grep " [c]ron$"; ps aux | grep " [a]uditd$"; ps aux | grep "[/u]sr/sbin/sshd"; ps aux | grep "[r]syslogd$"').output

    expect(output).to include('cron')
    expect(output).to include('auditd')
    expect(output).to include('/usr/sbin/sshd -D')
    expect(output).to include('/usr/sbin/rsyslogd')
  end
end
