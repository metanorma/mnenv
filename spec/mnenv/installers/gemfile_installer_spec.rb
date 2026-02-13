# frozen_string_literal: true

RSpec.describe Mnenv::Installers::GemfileInstaller do
  let(:version) { '1.14.4' }
  let(:source) { 'gemfile' }
  let(:target_dir) { Dir.mktmpdir }
  let(:installer) { described_class.new(version, source: source, target_dir: target_dir) }
  let(:data_dir) { Dir.mktmpdir }
  let(:repo) { Mnenv::GemfileRepository.new(data_dir: data_dir) }

  before do
    # Create a test versions.yaml for the repository
    versions_file = File.join(data_dir, 'versions.yaml')
    test_versions = {
      'metadata' => {
        'source' => 'gemfile',
        'count' => 1,
        'latest_version' => version
      },
      'versions' => [
        { 'version' => version, 'parsed_at' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ') }
      ]
    }
    File.write(versions_file, test_versions.to_yaml)
  end

  after do
    FileUtils.rm_rf(target_dir) if Dir.exist?(target_dir)
    FileUtils.rm_rf(data_dir) if Dir.exist?(data_dir)
  end

  describe '#initialize' do
    it 'creates a gemfile installer with version' do
      expect(installer.version).to eq(version)
      expect(installer.source).to eq(source)
    end
  end

  describe '#verify_prerequisites!' do
    context 'when version exists in repository' do
      it 'does not raise an error' do
        skip 'Needs a version in the repository' unless repo.exists?(version)

        expect { installer.send(:verify_prerequisites!) }.not_to raise_error
      end
    end

    context 'when version does not exist in repository' do
      it 'raises InstallationError' do
        installer = described_class.new('99.99.99', source: source, target_dir: target_dir)

        expect { installer.send(:verify_prerequisites!) }.to raise_error(
          Mnenv::Installer::InstallationError,
          /Version 99\.99\.99 not found/
        )
      end
    end

    context 'when development tools are missing' do
      it 'raises DevelopmentToolsMissing for missing ruby' do
        skip 'Needs mocking of system calls' do
          # This would require stubbing system('which', 'ruby')
          expect { installer.send(:verify_prerequisites!) }.to raise_error(
            Mnenv::Installer::DevelopmentToolsMissing,
            /Development tools required/
          )
        end
      end
    end
  end

  describe '#copy_gemfiles' do
    context 'when version exists locally' do
      it 'copies Gemfile and Gemfile.lock to target directory' do
        skip 'Needs a version with gemfiles' do
          installer.send(:copy_gemfiles)

          expect(File.exist?(File.join(target_dir, 'Gemfile'))).to be true
          expect(File.exist?(File.join(target_dir, 'Gemfile.lock.archived'))).to be true
        end
      end
    end
  end

  describe '#bundle_install' do
    context 'when gemfiles are present' do
      it 'runs bundle install with --path and --binstubs' do
        skip 'Requires actual bundle install - integration test' do
          # Create gemfiles first
          FileUtils.mkdir_p(target_dir)
          File.write(File.join(target_dir, 'Gemfile'), "source 'https://rubygems.org'")

          # This would actually run bundle install
          # installer.send(:bundle_install)

          # expect(File.exist?(File.join(target_dir, 'bin'))).to be true
        end
      end
    end
  end

  describe '#install' do
    it 'calls the installation steps in order' do
      skip 'Integration test with actual gemfiles' do
        # Verify the full install process
      end
    end
  end

  describe '#installed?' do
    it 'inherits from Installer base class' do
      expect(installer).to respond_to(:installed?)
    end
  end
end
