# frozen_string_literal: true

RSpec.describe Mnenv::Installer do
  let(:version) { '1.14.4' }
  let(:source) { 'gemfile' }
  let(:target_dir) { Dir.mktmpdir }
  let(:installer) { described_class.new(version, source: source, target_dir: target_dir) }

  after do
    FileUtils.rm_rf(target_dir) if Dir.exist?(target_dir)
  end

  describe '#initialize' do
    it 'creates an installer with version and source' do
      expect(installer.version).to eq(version)
      expect(installer.source).to eq(source)
    end

    it 'uses default source when none provided' do
      installer = described_class.new(version)
      expect(installer.source).to eq('gemfile') # Default from global source file
    end

    it 'uses default target dir when none provided' do
      installer = described_class.new(version, source: source)
      expected_dir = File.expand_path("~/.mnenv/versions/#{version}")
      expect(installer.instance_variable_get(:@target_dir)).to eq(expected_dir)
    end
  end

  describe '#install' do
    it 'raises NotImplementedError - subclasses must implement' do
      expect { installer.install }.to raise_error(NotImplementedError)
    end
  end

  describe '#installed?' do
    it 'returns true when version directory exists' do
      FileUtils.mkdir_p(target_dir)
      expect(installer.installed?).to be true
    end

    it 'returns false when version directory does not exist' do
      non_existent_dir = File.join(Dir.tmpdir, 'mnenv-test-nonexistent')
      installer = described_class.new(version, source: source, target_dir: non_existent_dir)
      expect(installer.installed?).to be false
    end
  end

  describe Mnenv::Installer::InstallationError do
    it 'is a StandardError subclass' do
      expect { raise Mnenv::Installer::InstallationError }.to raise_error(Mnenv::Installer::InstallationError)
    end
  end

  describe Mnenv::Installer::DevelopmentToolsMissing do
    it 'is an InstallationError subclass' do
      expect { raise Mnenv::Installer::DevelopmentToolsMissing }.to raise_error(Mnenv::Installer::DevelopmentToolsMissing)
    end
  end
end
