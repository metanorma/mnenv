# frozen_string_literal: true

RSpec.describe Mnenv::Installers::BinaryInstaller do
  let(:version) { '1.14.4' }
  let(:source) { 'binary' }
  let(:target_dir) { Dir.mktmpdir }
  let(:installer) { described_class.new(version, source: source, target_dir: target_dir) }

  after do
    FileUtils.rm_rf(target_dir) if Dir.exist?(target_dir)
  end

  describe '#initialize' do
    it 'creates a binary installer with version' do
      expect(installer.version).to eq(version)
      expect(installer.source).to eq(source)
    end
  end

  describe '#verify_prerequisites!' do
    context 'when version exists in packed-mn releases' do
      it 'does not raise an error' do
        skip 'Requires network access to GitHub API' do
          # This would make a real API call
          expect { installer.send(:verify_prerequisites!) }.not_to raise_error
        end
      end
    end

    context 'when detecting platform' do
      it 'detects linux platform' do
        skip 'Requires stubbing RbConfig' do
          # installer.send(:detect_platform)
        end
      end

      it 'detects macos platform' do
        skip 'Requires stubbing RbConfig' do
          # installer.send(:detect_platform)
        end
      end

      it 'detects windows platform' do
        skip 'Requires stubbing RbConfig' do
          # installer.send(:detect_platform)
        end
      end

      it 'raises error for unsupported platform' do
        skip 'Requires stubbing RbConfig' do
          expect { installer.send(:detect_platform) }.to raise_error(
            Mnenv::Installer::InstallationError,
            /Unsupported platform/
          )
        end
      end
    end
  end

  describe '#perform_installation' do
    it 'downloads binary and makes it executable' do
      skip 'Integration test with real downloads' do
        # installer.send(:download_binary)
        # installer.send(:make_executable)
      end
    end
  end

  describe '#installed?' do
    it 'inherits from Installer base class' do
      expect(installer).to respond_to(:installed?)
    end
  end
end
