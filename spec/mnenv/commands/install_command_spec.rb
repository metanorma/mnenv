# frozen_string_literal: true

RSpec.describe Mnenv::InstallCommand do
  let(:command) { described_class.new }

  describe '#list' do
    it 'lists all available Metanorma versions', :skip_webmock do
      expect { command.list }.not_to raise_error
    end
  end

  describe '#install' do
    context 'with version specified' do
      it 'installs the specified version' do
        skip 'Integration test with real installation' do
          command.install('1.14.4')
        end
      end
    end

    context 'with interactive flag' do
      it 'prompts for version selection' do
        skip 'Integration test with TTY::Prompt' do
          command.install(nil, interactive: true)
        end
      end
    end

    context 'when version already installed' do
      it 'prompts for reinstallation' do
        skip 'Integration test with existing installation' do
          # command.install('1.14.4')
        end
      end
    end
  end
end
