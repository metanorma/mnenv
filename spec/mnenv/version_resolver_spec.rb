# frozen_string_literal: true

RSpec.describe Mnenv::VersionResolver do
  let(:resolver) { described_class.new }

  describe '#resolve_version' do
    context 'when METANORMA_VERSION env var is set' do
      before { stub_const('ENV', ENV.to_h.merge('METANORMA_VERSION' => '1.14.4')) }

      it 'returns the environment variable value' do
        expect(resolver.resolve_version).to eq('1.14.4')
      end
    end

    context 'when local .metanorma-version file exists' do
      let(:temp_dir) { Dir.mktmpdir }
      let(:version_file) { File.join(temp_dir, '.metanorma-version') }

      before do
        File.write(version_file, "1.14.3\n")
        allow(Dir).to receive(:pwd).and_return(temp_dir)
      end

      after { FileUtils.rm_rf(temp_dir) }

      it 'returns the local file content' do
        expect(resolver.resolve_version).to eq('1.14.3')
      end
    end

    context 'when global version file exists' do
      let(:temp_dir) { Dir.mktmpdir }

      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?)
          .with(Mnenv::Paths::VERSION_FILE).and_return(true)
        allow(File).to receive(:read)
          .with(Mnenv::Paths::VERSION_FILE).and_return("1.14.2\n")
        # Ensure local file doesn't exist
        allow(Dir).to receive(:pwd).and_return('/nonexistent')
      end

      after { FileUtils.rm_rf(temp_dir) }

      it 'returns the global file content' do
        expect(resolver.resolve_version).to eq('1.14.2')
      end
    end

    context 'when no version is set' do
      before do
        allow(resolver).to receive(:from_env).and_return(nil)
        allow(resolver).to receive(:from_local_file).and_return(nil)
        allow(resolver).to receive(:from_global_file).and_return(nil)
      end

      it 'returns nil' do
        expect(resolver.resolve_version).to be_nil
      end
    end
  end

  describe '#resolve_source' do
    context 'when METANORMA_SOURCE env var is set' do
      before { stub_const('ENV', ENV.to_h.merge('METANORMA_SOURCE' => 'binary')) }

      it 'returns the environment variable value' do
        expect(resolver.resolve_source).to eq('binary')
      end
    end

    context 'when no source is set' do
      before do
        allow(resolver).to receive(:from_env).and_return(nil)
        allow(resolver).to receive(:from_local_file).and_return(nil)
        allow(resolver).to receive(:from_global_file).and_return(nil)
      end

      it 'returns gemfile as default' do
        expect(resolver.resolve_source).to eq('gemfile')
      end
    end
  end

  describe '#resolve' do
    it 'returns a tuple of version and source' do
      allow(resolver).to receive_messages(resolve_version: '1.14.4', resolve_source: 'gemfile')

      expect(resolver.resolve).to eq(['1.14.4', 'gemfile'])
    end
  end

  describe '#version_set?' do
    context 'when version is set' do
      before { allow(resolver).to receive(:resolve_version).and_return('1.14.4') }

      it 'returns true' do
        expect(resolver.version_set?).to be true
      end
    end

    context 'when version is not set' do
      before { allow(resolver).to receive(:resolve_version).and_return(nil) }

      it 'returns false' do
        expect(resolver.version_set?).to be false
      end
    end
  end
end
