# frozen_string_literal: true

RSpec.describe Mnenv::GemfileVersion do
  describe '#initialize' do
    it 'creates a gemfile version with gemfile_exists default' do
      version = Mnenv::GemfileVersion.new(version: '1.2.3')
      expect(version.gemfile_exists).to be false
    end

    it 'creates a gemfile version with gemfile_exists true' do
      version = Mnenv::GemfileVersion.new(
        version: '1.2.3',
        gemfile_exists: true
      )
      expect(version.gemfile_exists).to be true
    end
  end

  describe '#directory_path' do
    it 'returns the correct directory path' do
      version = Mnenv::GemfileVersion.new(version: '1.2.3')
      expect(version.directory_path).to match(%r{/data/gemfile/v1\.2\.3\z})
    end
  end

  describe '#gemfile_path_calc' do
    it 'returns the correct gemfile path' do
      version = Mnenv::GemfileVersion.new(version: '1.2.3')
      expect(version.gemfile_path_calc).to match(%r{/v1\.2\.3/Gemfile\z})
    end
  end

  describe '#gemfile_lock_path_calc' do
    it 'returns the correct gemfile.lock.archived path' do
      version = Mnenv::GemfileVersion.new(version: '1.2.3')
      expect(version.gemfile_lock_path_calc).to match(%r{/v1\.2\.3/Gemfile\.lock\.archived\z})
    end
  end
end
