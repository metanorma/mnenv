# frozen_string_literal: true

RSpec.describe Mnenv::VersionCommand do
  let(:command) { described_class.new }

  describe '#global' do
    it 'writes version to ~/.mnenv/version' do
      skip 'Integration test with actual file writing' do
        command.global('1.14.4')
      end
    end
  end

  describe '#local' do
    it 'creates .metanorma-version file' do
      skip 'Integration test with actual file writing' do
        command.local('1.14.4')
      end
    end
  end

  describe '#versions' do
    it 'lists all installed versions' do
      expect { command.versions }.not_to raise_error
    end
  end

  describe '#use' do
    it 'outputs export commands for current shell' do
      skip 'Integration test with actual output' do
        command.use('1.14.4')
      end
    end
  end
end
