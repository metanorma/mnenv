# frozen_string_literal: true

RSpec.describe Mnenv::PlatformDetector do
  describe '.os' do
    context 'on linux' do
      before do
        stub_const('RbConfig::CONFIG', RbConfig::CONFIG.merge('host_os' => 'linux-gnu'))
      end

      it 'returns linux' do
        expect(described_class.os).to eq('linux')
      end
    end

    context 'on darwin' do
      before do
        stub_const('RbConfig::CONFIG', RbConfig::CONFIG.merge('host_os' => 'darwin22.0'))
      end

      it 'returns darwin' do
        expect(described_class.os).to eq('darwin')
      end
    end

    context 'on windows' do
      before do
        stub_const('RbConfig::CONFIG', RbConfig::CONFIG.merge('host_os' => 'mswin32'))
      end

      it 'returns windows' do
        expect(described_class.os).to eq('windows')
      end
    end

    context 'on unsupported platform' do
      before do
        stub_const('RbConfig::CONFIG', RbConfig::CONFIG.merge('host_os' => 'unknown'))
      end

      it 'raises UnsupportedPlatform' do
        expect { described_class.os }.to raise_error(Mnenv::PlatformDetector::UnsupportedPlatform)
      end
    end
  end

  describe '.arch' do
    context 'on arm64' do
      before do
        stub_const('RbConfig::CONFIG', RbConfig::CONFIG.merge('host_cpu' => 'aarch64'))
      end

      it 'returns arm64' do
        expect(described_class.arch).to eq('arm64')
      end
    end

    context 'on x86_64' do
      before do
        stub_const('RbConfig::CONFIG', RbConfig::CONFIG.merge('host_cpu' => 'x86_64'))
      end

      it 'returns x86_64' do
        expect(described_class.arch).to eq('x86_64')
      end
    end

    context 'on unknown architecture' do
      before do
        stub_const('RbConfig::CONFIG', RbConfig::CONFIG.merge('host_cpu' => 'unknown'))
      end

      it 'defaults to x86_64' do
        expect(described_class.arch).to eq('x86_64')
      end
    end
  end

  describe '.variant' do
    context 'on non-linux' do
      before do
        allow(described_class).to receive(:os).and_return('darwin')
      end

      it 'returns nil' do
        expect(described_class.variant).to be_nil
      end
    end

    context 'on linux with musl' do
      before do
        allow(described_class).to receive(:os).and_return('linux')
        allow(described_class).to receive(:musl?).and_return(true)
      end

      it 'returns musl' do
        expect(described_class.variant).to eq('musl')
      end
    end

    context 'on linux with glibc' do
      before do
        allow(described_class).to receive(:os).and_return('linux')
        allow(described_class).to receive(:musl?).and_return(false)
      end

      it 'returns nil' do
        expect(described_class.variant).to be_nil
      end
    end
  end

  describe '.to_h' do
    before do
      allow(described_class).to receive(:os).and_return('linux')
      allow(described_class).to receive(:arch).and_return('x86_64')
      allow(described_class).to receive(:variant).and_return(nil)
    end

    it 'returns a hash with os, arch, and variant' do
      expect(described_class.to_h).to eq({ os: 'linux', arch: 'x86_64', variant: nil })
    end
  end

  describe '.platform_string' do
    context 'on linux glibc' do
      before do
        allow(described_class).to receive_messages(os: 'linux', arch: 'x86_64', variant: nil)
      end

      it 'returns linux-x86_64' do
        expect(described_class.platform_string).to eq('linux-x86_64')
      end
    end

    context 'on linux musl' do
      before do
        allow(described_class).to receive_messages(os: 'linux', arch: 'x86_64', variant: 'musl')
      end

      it 'returns linux-musl-x86_64' do
        expect(described_class.platform_string).to eq('linux-musl-x86_64')
      end
    end

    context 'on macos arm64' do
      before do
        allow(described_class).to receive_messages(os: 'darwin', arch: 'arm64', variant: nil)
      end

      it 'returns darwin-arm64' do
        expect(described_class.platform_string).to eq('darwin-arm64')
      end
    end
  end

  describe '.platform_candidates' do
    context 'on linux with musl' do
      before do
        allow(described_class).to receive_messages(os: 'linux', arch: 'x86_64', variant: 'musl')
      end

      it 'returns variant-specific first, then generic' do
        expect(described_class.platform_candidates).to eq(%w[linux-musl-x86_64 linux-x86_64])
      end
    end

    context 'on linux without musl' do
      before do
        allow(described_class).to receive_messages(os: 'linux', arch: 'x86_64', variant: nil)
      end

      it 'returns only generic' do
        expect(described_class.platform_candidates).to eq(['linux-x86_64'])
      end
    end
  end
end
