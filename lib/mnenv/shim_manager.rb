# frozen_string_literal: true

require 'set'
require_relative 'shells/factory'

module Mnenv
  class ShimManager
    RESOLVER_SCRIPT = File.expand_path('resolver', __dir__).freeze

    attr_reader :shims_dir, :installed_dir

    def initialize(shims_dir: nil, installed_dir: nil)
      @shims_dir = shims_dir || Paths::SHIMS_DIR
      @installed_dir = installed_dir || Paths::INSTALLED_DIR
    end

    def regenerate_all
      FileUtils.mkdir_p(@shims_dir)
      FileUtils.mkdir_p(Paths::LIB_DIR)

      # Copy resolver script to mnenv lib directory (for Unix shells)
      if File.exist?(RESOLVER_SCRIPT)
        FileUtils.cp(RESOLVER_SCRIPT, File.join(Paths::LIB_DIR, 'resolver'))
        File.chmod(0o755, File.join(Paths::LIB_DIR, 'resolver'))
      end

      executables = discover_executables

      executables.each do |exe|
        create_shims(exe)
      end

      remove_obsolete_shims(executables)
    end

    def create_shims(executable_name)
      # Create shims for all platform-appropriate shells
      Shells::ShellFactory.platform_shells.each do |shell|
        create_shim_for_shell(executable_name, shell)
      end
    end

    private

    def create_shim_for_shell(executable_name, shell)
      # For bash, no extension; for PowerShell, .ps1; for CMD, .bat
      extension = shell.shim_extension
      shim_name = executable_name + extension
      shim_path = File.join(@shims_dir, shim_name)

      File.write(shim_path, shell.shim_content(executable_name))
      File.chmod(0o755, shim_path) unless shell.windows?
    end

    def discover_executables
      executables = Set.new

      # Scan installed directories with new naming convention: <version>-<source>
      Dir.glob(File.join(@installed_dir, '*')).each do |version_dir|
        next unless File.directory?(version_dir)

        dir_name = File.basename(version_dir)
        version, source = Paths.parse_version_dir(dir_name)
        next unless version && source

        case source
        when 'gemfile'
          # Discover binstubs from bundle install
          bin_dir = File.join(version_dir, 'bin')
          next unless Dir.exist?(bin_dir)

          Dir.glob(File.join(bin_dir, '*')).each do |bin_path|
            next if File.directory?(bin_path)

            basename = File.basename(bin_path)

            # On Windows, bundler creates both 'command' and 'command.cmd'
            # Skip .cmd and .bat files - we'll create shims from the base name
            next if windows? && (basename.end_with?('.cmd') || basename.end_with?('.bat'))

            executables << basename if windows? || File.executable?(bin_path)
          end

        when 'binary'
          # Binary installations have a single metanorma binary
          binary_path = File.join(version_dir, 'metanorma')
          exe_path = File.join(version_dir, 'metanorma.exe')

          if File.exist?(binary_path) && (File.executable?(binary_path) || windows?)
            executables << 'metanorma'
          elsif File.exist?(exe_path)
            executables << 'metanorma'
          end
        end
      end

      executables.to_a.sort
    end

    def remove_obsolete_shims(valid_executables)
      # Build list of valid shim names (with extensions)
      valid_shim_names = Set.new
      Shells::ShellFactory.platform_shells.each do |shell|
        valid_executables.each do |exe|
          valid_shim_names << exe + shell.shim_extension
        end
      end

      Dir.glob(File.join(@shims_dir, '*')).each do |shim_path|
        next if File.directory?(shim_path)

        shim_name = File.basename(shim_path)
        File.delete(shim_path) unless valid_shim_names.include?(shim_name)
      end
    end

    def windows?
      RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
    end
  end
end
