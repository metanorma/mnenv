# frozen_string_literal: true

RSpec.describe Mnenv::InstallerFactory do
  describe '.create' do
    context 'with gemfile source' do
      it 'creates a GemfileInstaller' do
        installer = described_class.create('1.14.4', source: 'gemfile')
        expect(installer).to be_a(Mnenv::Installers::GemfileInstaller)
        expect(installer.version).to eq('1.14.4')
        expect(installer.source).to eq('gemfile')
      end
    end

    context 'with binary source' do
      it 'creates a BinaryInstaller' do
        installer = described_class.create('1.14.4', source: 'binary')
        expect(installer).to be_a(Mnenv::Installers::BinaryInstaller)
        expect(installer.version).to eq('1.14.4')
        expect(installer.source).to eq('binary')
      end
    end

    context 'with unknown source' do
      it 'raises InstallationError' do
        expect do
          described_class.create('1.14.4', source: 'unknown')
        end.to raise_error(
          Mnenv::Installer::InstallationError,
          /Unknown source: unknown/
        )
      end
    end

    context 'with symbol source' do
      it 'converts symbol to string' do
        installer = described_class.create('1.14.4', source: :gemfile)
        expect(installer).to be_a(Mnenv::Installers::GemfileInstaller)
      end
    end
  end
end
