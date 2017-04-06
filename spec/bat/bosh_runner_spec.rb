require 'spec_helper'
require 'bat/bosh_runner'
require 'logger'

describe Bat::BoshRunner do
  subject { described_class.new('fake-bosh-exe', 'fake-path-to-bosh-config', 'admin', 'admin', ca_cert, logger) }

  let(:logger) { instance_double('Logger', info: nil) }
  let(:ca_cert) { nil }
  let(:bosh_exec) { class_double('Bosh::Exec').as_stubbed_const(transfer_nested_constants: true) }
  let(:bosh_exec_result) { instance_double('Bosh::Exec::Result', output: 'FAKE_OUTPUT') }

  describe '#bosh' do
    it 'uses Bosh::Exec to shell out to bosh' do
      expected_command = %W(
        fake-bosh-exe
        --non-interactive
        --json
        --config fake-path-to-bosh-config
        --client admin --client-secret admin
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

      before(:each) do
        subject.set_environment('10.0.0.10')
      end

      context 'when ca_cert is given as content represented as string' do
        let(:ca_cert) { '-----BEGIN CERTIFICATE-----\nCACERT\n-----END CERTIFICATE-----' }

        it 'passes the ca_cert to Bosh::Exec' do
          expected_command = %W(
        fake-bosh-exe
        --non-interactive
        --environment 10.0.0.10
        --json
        --config fake-path-to-bosh-config
        --client admin --client-secret admin
        --ca-cert '-----BEGIN CERTIFICATE-----\nCACERT\n-----END CERTIFICATE-----'
        FAKE_ARGS 2>&1
      ).join(' ')

          expect(bosh_exec).to receive(:sh).with(expected_command, {}).and_return(bosh_exec_result)
          subject.bosh('FAKE_ARGS')
        end
      end

      context 'when ca_cert is given as path to a file' do
        let(:ca_cert) { '/some/ca_cert/file' }

        it 'passes the ca_cert to Bosh::Exec' do
          expected_command = %W(
        fake-bosh-exe
        --non-interactive
        --environment 10.0.0.10
        --json
        --config fake-path-to-bosh-config
        --client admin --client-secret admin
        --ca-cert '/some/ca_cert/file'
        FAKE_ARGS 2>&1
      ).join(' ')

          expect(bosh_exec).to receive(:sh).with(expected_command, {}).and_return(bosh_exec_result)
          subject.bosh('FAKE_ARGS')
        end
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
            --config fake-path-to-bosh-config
            --client admin --client-secret admin
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

  describe '#set_director' do
    let(:env) { 'my.bosh.director' }

    it 'causes all future invocations of #bosh to add `--environment <env>`' do
      expected_command = %W(
        fake-bosh-exe
        --non-interactive
        --json
        --config fake-path-to-bosh-config
        --client admin --client-secret admin
        FAKE_ARGS 2>&1
      ).join(' ')

      expect(bosh_exec).to receive(:sh).with(expected_command, {}).and_return(bosh_exec_result)

      subject.bosh('FAKE_ARGS')

      expected_command = %W(
        fake-bosh-exe
        --non-interactive
        --environment #{env}
        --json
        --config fake-path-to-bosh-config
        --client admin --client-secret admin
        FAKE_ARGS 2>&1
      ).join(' ')

      subject.set_environment(env)

      expect(bosh_exec).to receive(:sh).with(expected_command, {}).and_return(bosh_exec_result)

      subject.bosh('FAKE_ARGS')
    end
  end
end
