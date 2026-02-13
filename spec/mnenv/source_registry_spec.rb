# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Mnenv::SourceRegistry do
  before do
    # Clear registry before each test for isolation
    described_class.clear
  end

  describe '.register' do
    it 'registers a new source' do
      expect do
        described_class.register(
          name: 'test_source',
          repository: Class.new,
          model: Class.new
        )
      end.not_to raise_error
    end

    it 'raises error when registering duplicate source' do
      described_class.register(
        name: 'test_source',
        repository: Class.new,
        model: Class.new
      )

      expect do
        described_class.register(
          name: 'test_source',
          repository: Class.new,
          model: Class.new
        )
      end.to raise_error(Mnenv::SourceRegistry::DuplicateSourceError, /already registered/)
    end

    it 'accepts optional installer parameter' do
      expect do
        described_class.register(
          name: 'with_installer',
          repository: Class.new,
          model: Class.new,
          installer: Class.new
        )
      end.not_to raise_error
    end
  end

  describe '.repository' do
    it 'returns registered repository class' do
      repo_class = Class.new
      described_class.register(
        name: 'test',
        repository: repo_class,
        model: Class.new
      )

      expect(described_class.repository('test')).to eq(repo_class)
    end

    it 'accepts symbol as name' do
      repo_class = Class.new
      described_class.register(
        name: 'symbol_test',
        repository: repo_class,
        model: Class.new
      )

      expect(described_class.repository(:symbol_test)).to eq(repo_class)
    end

    it 'raises error for unknown source' do
      expect do
        described_class.repository('unknown')
      end.to raise_error(Mnenv::SourceRegistry::UnknownSourceError, /Unknown source/)
    end
  end

  describe '.model' do
    it 'returns registered model class' do
      model_class = Class.new
      described_class.register(
        name: 'model_test',
        repository: Class.new,
        model: model_class
      )

      expect(described_class.model('model_test')).to eq(model_class)
    end
  end

  describe '.installer' do
    it 'returns registered installer class' do
      installer_class = Class.new
      described_class.register(
        name: 'installer_test',
        repository: Class.new,
        model: Class.new,
        installer: installer_class
      )

      expect(described_class.installer('installer_test')).to eq(installer_class)
    end

    it 'returns nil when no installer registered' do
      described_class.register(
        name: 'no_installer',
        repository: Class.new,
        model: Class.new
      )

      expect(described_class.installer('no_installer')).to be_nil
    end
  end

  describe '.all_names' do
    it 'returns empty array when no sources registered' do
      expect(described_class.all_names).to eq([])
    end

    it 'returns all registered source names sorted' do
      described_class.register(name: 'zeta', repository: Class.new, model: Class.new)
      described_class.register(name: 'alpha', repository: Class.new, model: Class.new)
      described_class.register(name: 'beta', repository: Class.new, model: Class.new)

      expect(described_class.all_names).to eq(%w[alpha beta zeta])
    end
  end

  describe '.registered?' do
    it 'returns true for registered source' do
      described_class.register(name: 'registered', repository: Class.new, model: Class.new)

      expect(described_class.registered?('registered')).to be true
    end

    it 'returns false for unregistered source' do
      expect(described_class.registered?('not_registered')).to be false
    end

    it 'accepts symbol as name' do
      described_class.register(name: 'symbol_check', repository: Class.new, model: Class.new)

      expect(described_class.registered?(:symbol_check)).to be true
    end
  end

  describe '.clear' do
    it 'removes all registered sources' do
      described_class.register(name: 'to_clear', repository: Class.new, model: Class.new)
      expect(described_class.all_names).to eq(['to_clear'])

      described_class.clear
      expect(described_class.all_names).to eq([])
    end
  end
end
