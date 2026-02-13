# frozen_string_literal: true

RSpec.describe Mnenv::UninstallCommand do
  let(:command) { described_class.new }

  describe '#uninstall' do
    it 'removes the version directory' do
      skip 'Integration test with actual uninstallation' do
        command.uninstall('1.14.4')
      end
    end

    it 'prompts for confirmation without force flag' do
      skip 'Integration test with TTY::Prompt' do
        command.uninstall('1.14.4')
      end
    end

    it 'skips confirmation with force flag' do
      skip 'Integration test with actual uninstallation' do
        command.uninstall('1.14.4', force: true)
      end
    end

    it 'regenerates shims after uninstallation' do
      skip 'Integration test with shim regeneration' do
        command.uninstall('1.14.4')
      end
    end
  end
end
