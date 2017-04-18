require 'spec_helper'
require 'bat/bosh_runner'
require 'logger'

describe Bat::BoshRunner do
  subject { described_class.new('fake-bosh-exe', logger) }

  let(:logger) { instance_double('Logger', info: nil) }
  let(:bosh_exec) { class_double('Bosh::Exec').as_stubbed_const(transfer_nested_constants: true) }

  describe '#bosh' do
    let(:bosh_exec_result) { instance_double('Bosh::Exec::Result', output: 'FAKE_OUTPUT') }

    it 'uses Bosh::Exec to shell out to bosh' do
      expected_command = %W(
        fake-bosh-exe
        --non-interactive
        --json
        FAKE_ARGS 2>&1
      ).join(' ')

      expect(logger).to receive(:info).with("Running bosh command --> #{expected_command}")
      expect(bosh_exec).to receive(:sh).with(expected_command, {}).and_return(bosh_exec_result)

      subject.bosh('FAKE_ARGS')
    end

    it 'returns the result of Bosh::Exec' do
      allow(bosh_exec).to receive(:sh).and_return(bosh_exec_result)

      expect(subject.bosh('FAKE_ARGS')).to eq(bosh_exec_result)
    end

    context 'when a ca_cert is provided' do
      let(:ca_cert) { 'CACERT' }

      it 'passes the ca_cert to Bosh::Exec' do
        expected_command = %W(
        fake-bosh-exe
        --non-interactive
        --json
        FAKE_ARGS 2>&1
      ).join(' ')

        expect(bosh_exec).to receive(:sh).with(expected_command, {}).and_return(bosh_exec_result)
        subject.bosh('FAKE_ARGS')
      end
    end

    context 'when options are passed' do
      it 'passes the options to Bosh::Exec' do
        expect(bosh_exec).to receive(:sh).with(anything, {foo: :bar}).and_return(bosh_exec_result)

        subject.bosh('FAKE_ARGS', {foo: :bar})
      end

      context 'when deployment option is passed' do
        it 'removes the option from Bosh::Exec call' do
          expected_command = %W(
            fake-bosh-exe
            --non-interactive
            --json
            --deployment bat
            FAKE_ARGS 2>&1
          ).join(' ')

          expect(bosh_exec).to receive(:sh).with(expected_command, {foo: :bar}).and_return(bosh_exec_result)

          subject.bosh('FAKE_ARGS', {foo: :bar, deployment: 'bat'})
        end
      end
    end

    context 'when bosh command raises an error' do
      it 'prints Bosh::Exec::Error messages and re-raises' do
        allow(bosh_exec).to receive(:sh).and_raise(Bosh::Exec::Error.new(1, 'fake command', 'fake output'))

        expect(logger).to receive(:info).with('Bosh command failed: fake output')
        expect {
          subject.bosh('FAKE_ARG')
        }.to raise_error(Bosh::Exec::Error, /fake command/)
      end
    end

    it 'prints the output from the Bosh::Exec result' do
      allow(bosh_exec).to receive(:sh).and_return(bosh_exec_result)

      expect(logger).to receive(:info).with('FAKE_OUTPUT')

      subject.bosh('fake arg')
    end

    context 'when a block is passed' do
      it 'yields the Bosh::Exec result' do
        allow(bosh_exec).to receive(:sh).and_return(bosh_exec_result)

        expect { |b|
          subject.bosh('fake arg', &b)
        }.to yield_with_args(bosh_exec_result)
      end
    end
  end

  describe '#deployments' do
    let(:output_json) { JSON.dump({ Tables: [ Rows: [ { name: "some-deployment" } ]] }) }
    let(:bosh_exec_result) { instance_double('Bosh::Exec::Result', output: output_json) }

    it 'returns a hash of the current deployments' do
      allow(bosh_exec).to receive(:sh).and_return(bosh_exec_result)

      deployments_output = subject.deployments
      expect(deployments_output['some-deployment']).to eq(true)
    end
  end

  describe '#releases' do
    let(:output_json) { JSON.dump({ Tables: [Rows: [ { name: "some-release" }]] }) }
    let(:bosh_exec_result) { instance_double('Bosh::Exec::Result', output: output_json) }

    it 'returns a list of releases' do
      allow(bosh_exec).to receive(:sh).and_return(bosh_exec_result)

      releases = subject.releases
      expect(releases.length).to eq(1)
      expect(releases[0].name).to eq('some-release')
    end
  end

  describe '#stemcells' do
    let(:output_json) { JSON.dump({ Tables: [ Rows: [ { name: "some-stemcell", version: "fake-version" } ]] }) }
    let(:bosh_exec_result) { instance_double('Bosh::Exec::Result', output: output_json) }

    it 'returns a list of stemcells with name and version' do
      allow(bosh_exec).to receive(:sh).and_return(bosh_exec_result)

      stemcells = subject.stemcells
      expect(stemcells.length).to eq(1)
      expect(stemcells[0].name).to eq('some-stemcell')
      expect(stemcells[0].version).to eq('fake-version')
    end
  end
end
