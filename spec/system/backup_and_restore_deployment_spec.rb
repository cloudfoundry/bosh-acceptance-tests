require 'system/spec_helper'

describe 'back and restore deployment' do
  # before(:all) do
  #   @requirements.requirement(@requirements.stemcell)
  #   @requirements.requirement(@requirements.release)
  # end
  #
  # before(:all) do
  #   load_deployment_spec
  #   use_static_ip
  #   use_vip
  #   @requirements.requirement(deployment, @spec) # 2.5 min on local vsphere
  # end
  #
  # after(:all) do
  #   @requirements.cleanup(deployment)
  # end

  xit 'should restore director DB' do
    with_tmpdir do
      expect(bosh_safe('backup one_deployment.tgz')).to succeed_with /Backup of BOSH director was put in.*one_deployment\.tgz/
      expect(bosh_safe("-d #{deployment_name} delete-deployment")).to succeed_with /Deleted deployment/
      expect(bosh_safe('backup no_deployment.tgz')).to succeed_with /Backup of BOSH director was put in.*no_deployment\.tgz/
      expect(bosh_safe('restore one_deployment.tgz')).to succeed_with /Restore done!/
      expect(bosh_safe('deployments')).to succeed_with /#{deployment_name}/
      expect(bosh_safe('restore no_deployment.tgz')).to succeed_with /Restore done!/
      result = bosh_safe('deployments')
      expect(result.output).to match_regex(/No deployments/)
    end
  end
end
