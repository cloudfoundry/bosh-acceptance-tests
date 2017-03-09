require 'rspec'
require 'bat/env'

describe Bat::Env do
  context 'when required env vars are missing' do
    let(:env_vars) { {} }

    it 'raises an ArgumentError' do
      expect{
        Bat::Env.new(env_vars)
      }.to raise_error(ArgumentError)
    end
  end

  context 'when required env vars are all existing' do
    before(:each) { @env = Bat::Env.new(env_vars) }
    let(:env_vars) { required_vars }

    it 'should expose the values as instance variables' do
      required_vars.each do |key, val|
        expect(@env.instance_variable_get("@#{key}")).to eq(val)
      end
    end

    describe 'optional env vars' do
      let(:env_vars) { required_vars.merge({vcap_private_key: 'BAT_VCAP_PRIVATE_KEY'}) }

      it 'exposes the values as instance variables' do
        expect(@env.vcap_private_key).to eq('BAT_VCAP_PRIVATE_KEY')
      end

      it 'does not contain an optional value which was not provided' do
        expect(@env.instance_variable_defined? '@debug_mode').to be false
      end

      context 'env_vars include a director_ca' do
        let(:env_vars) { required_vars.merge({director_ca: 'BAT_DIRECTOR_CA'}) }

        it 'sets director_ca' do
          expect(@env.director_ca).to eq('BAT_DIRECTOR_CA')
        end
      end

      context 'when default value exists' do
        let(:env_vars) { required_vars.merge({director_user: 'my_user'}) }

        it 'takes the default value, if no value is provided' do
          expect(@env.director_password).to eq('admin')
        end

        it 'takes the provided value' do
          expect(@env.director_user).to eq('my_user')
        end
      end
    end
  end

  def required_vars
    {
        director:             'director',
        bosh_cli_path:        '/path/bosh-cli',
        stemcell_path:        '/path/stemcell',
        deployment_spec_path: 'BAT_DEPLOYMENT_SPEC',
        vcap_password:        'BAT_VCAP_PASSWORD',
        dns_host:             'BAT_DNS_HOST',
        bat_infrastructure:   'BAT_INFRASTRUCTURE',
        bat_networking:       'BAT_NETWORKING',
    }
  end

end
