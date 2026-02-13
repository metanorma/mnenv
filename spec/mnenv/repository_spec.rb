# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Mnenv::GemfileRepository do
  let(:data_dir) { Dir.mktmpdir }
  let(:versions_file) { File.join(data_dir, 'versions.yaml') }
  let(:repo) { described_class.new(data_dir: data_dir) }

  after { FileUtils.rm_rf(data_dir) }

  # Helper to create a minimal versions.yaml for testing
  def create_test_versions_file(versions = [])
    content = {
      'metadata' => {
        'source' => 'gemfile',
        'count' => versions.size
      },
      'versions' => versions.map do |v|
        { 'version' => v, 'parsed_at' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ') }
      end
    }
    File.write(versions_file, content.to_yaml)
  end

  describe '#initialize' do
    it 'creates a new repository with data_dir' do
      create_test_versions_file
      expect(repo.data_dir).to eq(data_dir)
      expect(repo.versions_file_path).to eq(versions_file)
    end

    it 'creates empty cache when versions file is empty' do
      create_test_versions_file([])
      expect(repo.all).to eq([])
      expect(repo.count).to eq(0)
    end

    it 'loads versions from local file when it exists' do
      create_test_versions_file(['1.2.3', '1.2.4'])
      expect(repo.count).to eq(2)
      expect(repo.all.map(&:version)).to eq(['1.2.3', '1.2.4'])
    end

    it 'fetches from remote when no local file exists', :skip_webmock do
      # Don't create a versions file - should fetch from remote
      remote_repo = described_class.new(data_dir: nil)
      expect(remote_repo.count).to be > 0
    end
  end

  describe '#save and #find' do
    before { create_test_versions_file }

    it 'saves and retrieves a version' do
      version = Mnenv::ArtifactVersion.new(version: '1.2.3')
      repo.save(version)

      expect(repo.find('1.2.3')).to eq(version)
      expect(repo.exists?('1.2.3')).to be true
    end

    it 'persists versions to YAML file' do
      version = Mnenv::ArtifactVersion.new(version: '1.2.3')
      repo.save(version)

      # Create new repo instance to test persistence
      repo2 = described_class.new(data_dir: data_dir)
      expect(repo2.find('1.2.3').version).to eq('1.2.3')
    end
  end

  describe '#save_all' do
    before { create_test_versions_file }

    it 'saves multiple versions' do
      versions = [
        Mnenv::ArtifactVersion.new(version: '1.2.3'),
        Mnenv::ArtifactVersion.new(version: '1.2.4'),
        Mnenv::ArtifactVersion.new(version: '1.3.0')
      ]

      repo.save_all(versions)

      expect(repo.count).to eq(3)
      expect(repo.all.map(&:version)).to eq(['1.2.3', '1.2.4', '1.3.0'])
    end
  end

  describe '#latest' do
    before { create_test_versions_file }

    it 'returns the highest version' do
      versions = [
        Mnenv::ArtifactVersion.new(version: '1.2.3'),
        Mnenv::ArtifactVersion.new(version: '1.3.0'),
        Mnenv::ArtifactVersion.new(version: '1.2.4')
      ]

      repo.save_all(versions)

      expect(repo.latest.version).to eq('1.3.0')
    end

    it 'returns nil when no versions exist' do
      expect(repo.latest).to be_nil
    end
  end
end
