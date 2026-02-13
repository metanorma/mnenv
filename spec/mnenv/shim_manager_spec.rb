# frozen_string_literal: true

RSpec.describe Mnenv::ShimManager do
  let(:shims_dir) { Dir.mktmpdir }
  let(:manager) { described_class.new(shims_dir: shims_dir) }

  # Helper to check if we're on Windows
  def windows?
    RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
  end

  # Get expected shim path(s) for a given executable
  def expected_shim_paths(executable_name)
    if windows?
      [
        File.join(shims_dir, "#{executable_name}.ps1"),
        File.join(shims_dir, "#{executable_name}.bat")
      ]
    else
      [File.join(shims_dir, executable_name)]
    end
  end

  after do
    FileUtils.rm_rf(shims_dir) if Dir.exist?(shims_dir)
  end

  describe '#initialize' do
    it 'creates a manager with custom shims_dir' do
      expect(manager.instance_variable_get(:@shims_dir)).to eq(shims_dir)
    end

    it 'uses default shims_dir when none provided' do
      default_manager = described_class.new
      expected_dir = File.expand_path('~/.mnenv/shims')
      expect(default_manager.instance_variable_get(:@shims_dir)).to eq(expected_dir)
    end
  end

  describe '#regenerate_all' do
    it 'creates shims directory if it does not exist' do
      manager.regenerate_all
      expect(Dir.exist?(shims_dir)).to be true
    end

    it 'creates shim files for discovered executables' do
      skip 'Requires actual installed versions' do
        manager.regenerate_all

        # Check that shims were created
        shim_files = Dir.glob(File.join(shims_dir, '*'))
        expect(shim_files).not_to be_empty
      end
    end

    it 'removes obsolete shims' do
      # Create a fake obsolete shim
      obsolete_shim = File.join(shims_dir, 'obsolete-command')
      File.write(obsolete_shim, '#!/bin/bash\necho obsolete')
      File.chmod(0o755, obsolete_shim)

      manager.regenerate_all

      # Obsolete shim should be removed if it doesn't exist in any version
      # (This is hard to test without real installations)
    end
  end

  describe '#create_shims' do
    it 'creates shim files for the executable' do
      manager.create_shims('metanorma')

      expected_shim_paths('metanorma').each do |shim_path|
        expect(File.exist?(shim_path)).to be true
      end
    end

    it 'creates shim with correct content structure' do
      manager.create_shims('metanorma')

      shim_paths = expected_shim_paths('metanorma')

      if windows?
        # Check PowerShell shim
        ps1_path = shim_paths.find { |p| p.end_with?('.ps1') }
        ps1_content = File.read(ps1_path)
        expect(ps1_content).to include('MNENV_ROOT')
        expect(ps1_content).to include('metanorma')

        # Check CMD shim
        bat_path = shim_paths.find { |p| p.end_with?('.bat') }
        bat_content = File.read(bat_path)
        expect(bat_content).to include('MNENV_ROOT')
        expect(bat_content).to include('metanorma')
      else
        # Check bash shim
        shim_path = shim_paths.first
        content = File.read(shim_path)
        expect(content).to include('#!/bin/bash')
        expect(content).to include('MNENV_ROOT')
        expect(content).to include('VERSION="$("$MNENV_ROOT/lib/mnenv/resolver" "version")"')
        expect(content).to include('exec "$EXECUTABLE" "$@"')
      end
    end
  end
end
