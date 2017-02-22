require 'system/spec_helper'

describe 'with release, stemcell and failed deployment', core: true do
  let(:deployment_manifest_bad) do
    use_failing_job
    with_deployment
  end

  let(:deployment_manifest_good) do
    with_deployment
  end

  before(:all) do
    @requirements.requirement(@requirements.stemcell)
    @requirements.requirement(@requirements.release)
  end

  before do
    load_deployment_spec
    use_canaries(1)
    use_pool_size(2)
    use_job_instances(2)
  end

  after do
    bosh("-d #{deployment_manifest_good.name} delete-deployment")

    deployment_manifest_good.delete
    deployment_manifest_bad.delete
  end

  context 'A brand new deployment' do
    it 'should stop the deployment if the canary fails' do
      failed_deployment_result = bosh_safe("-d #{deployment_manifest_bad.name} deploy #{deployment_manifest_bad.to_path}")

      # possibly check for:
      # Error 400007: 'batlight/0' is not running after update
      expect(failed_deployment_result).to_not succeed

      events(get_most_recent_task_id, 'error').each do |event|
        expect(event['task']).to_not match(/^batlight\/.* (1)/) if event['stage'] == 'Updating instance'
      end
    end
  end

  context 'A deployment already exists' do
    it 'should stop the deployment if the canary fails' do
      expect(bosh_safe("-d #{deployment_manifest_good.name} deploy #{deployment_manifest_good.to_path}")).to succeed

      # possibly check for:
      # Error 400007: 'batlight/0' is not running after update
      expect(bosh_safe("-d #{deployment_manifest_bad.name} deploy #{deployment_manifest_bad.to_path}")).to_not succeed

      events(get_most_recent_task_id, 'error').each do |event|
        expect(event['task']).to_not match(/^batlight\/.* (1)/) if event['stage'] == 'Updating instance'
      end
    end
  end
end
