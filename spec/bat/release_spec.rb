require 'spec_helper'
require 'bat/release'

describe Bat::Release do
  subject(:release) { Bat::Release.new(release_name, []) }
  let(:release_name) { 'FAKE_NAME' }

  describe '.from_path' do
    let(:bat_path) { '/tmp/fake/bat/path' }

    it 'creates a Release named "bat" with the given path' do
      result = Bat::Release.from_path(bat_path)
      expect(result.name).to eq('bat')
      expect(result.path).to eq(bat_path)
    end
  end

  describe '#initialize' do
    it 'sets name' do
      expect(Bat::Release.new('NAME', nil).name).to eq('NAME')
    end

    it 'sets path to nil' do
      expect(Bat::Release.new('NOT_PATH', []).path).to eq(nil)
    end

    context 'when a third argument is passed' do
      it 'sets path' do
        expect(Bat::Release.new(nil, nil, '/tmp/fake/path').path).to eq('/tmp/fake/path')
      end
    end
  end

  describe '#to_s' do
    it 'returns the name' do
      expect(release.to_s).to eq('FAKE_NAME')
    end
  end

  describe '#==' do
    it 'returns true if the other object is a Release with the same name' do
      expect(release == Bat::Release.new(release_name, [])).to be(true)
    end

    it 'returns false if the other object is a Release with a different name' do
      expect(release == Bat::Release.new('OTHER', [])).to be(false)
    end

    it 'returns false for non-Release objects' do
      expect(release == 'not a release').to be(false)
    end
  end
end
