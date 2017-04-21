require 'spec_helper'
require 'bat/requirements'
require 'bat/bosh_runner'
require 'bat/spec_state'
require 'logger'
require 'fileutils'
require 'common/exec'

describe Bat::Requirements do
  subject(:requirements) { described_class.new("/some-stemcell/path", bosh_runner, spec_state, logger) }
  let(:bosh_runner) { Bat::BoshRunner.new("bosh", logger) }
  let(:logger) { Logger.new('/dev/null') }
  let(:spec_state) { Bat::SpecState.new(false) }

  describe "#tasks_processing?" do
    let(:tasks_result) { Bosh::Exec::Result.new('bosh tasks', tasks_json, 0) }

    context "when non-ssh cleanup tasks are running" do
      let(:tasks_json) { <<'OUTPUT' }
{
  "Tables": [
    {
      "Rows": [
        {
          "description": "create deployment",
          "state": "done"
        }
      ]
    }
  ]
}
OUTPUT
      it "returns true " do
        expect(Bosh::Exec).to receive(:sh).with('bosh --non-interactive --json tasks 2>&1', {}).and_return(tasks_result)
        expect(requirements.tasks_processing?).to eq(true)
      end
    end

    context 'when the only running task is ssh cleanup' do
      let(:tasks_json) { <<'OUTPUT' }
{
  "Tables": [
    {
      "Rows": [
        {
          "description": "ssh: cleanup:{\"ids\"=\u004e[\"0\"], \"indexes\"=\u003e[\"0\"], \"job\"=\u003e\"fake\"}",
          "state": "done"
        }
      ]
    }
  ]
}
OUTPUT
      it 'returns false' do
        expect(Bosh::Exec).to receive(:sh).with('bosh --non-interactive --json tasks 2>&1', {}).and_return(tasks_result)
        expect(requirements.tasks_processing?).to eq(false)
      end
    end

    context 'when no tasks are processsing' do
      let(:tasks_json) { <<'OUTPUT' }
{
  "Tables": [
    {
      "Rows": []
    }
  ]
}
OUTPUT
      it 'returns false' do
        expect(Bosh::Exec).to receive(:sh).with('bosh --non-interactive --json tasks 2>&1', {}).and_return(tasks_result)
        expect(requirements.tasks_processing?).to eq(false)
      end
    end
  end
end
