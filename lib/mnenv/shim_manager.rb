# frozen_string_literal: true

require 'set'
require_relative 'shells/factory'

module Mnenv
  class ShimManager
    SHIMS_DIR = File.expand_path('~/.mnenv/shims').freeze
    VERSIONS_DIR = File.expand_path('~/.mnenv/versions').freeze
    RESOLVER_SCRIPT = File.expand_path('resolver', __dir__).freeze
    LIB_DIR = File.expand_path('~/.mnenv/lib/mnenv').freeze

    attr_reader :shims_dir

    def initialize(shims_dir: nil)
      @shims_dir = shims_dir || SHIMS_DIR
    end

    def regenerate_all
      FileUtils.mkdir_p(@shims_dir)
      FileUtils.mkdir_p(LIB_DIR)

      # Copy resolver script to mnenv lib directory (for Unix shells)
      if File.exist?(RESOLVER_SCRIPT)
        FileUtils.cp(RESOLVER_SCRIPT, File.join(LIB_DIR, 'resolver'))
        File.chmod(0o755, File.join(LIB_DIR, 'resolver'))
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

      # Discover from gemfile installations (binstubs in bin/)
      bin_pattern = File.join(VERSIONS_DIR, '*', 'bin', '*')
      Dir.glob(bin_pattern).each do |bin_path|
        next if File.directory?(bin_path)

        basename = File.basename(bin_path)

        # On Windows, bundler creates both 'command' and 'command.cmd'
        # We want to create shims for the base command name
        if windows?
          # Skip .cmd and .bat files - we'll create shims from the base name
          next if basename.end_with?('.cmd') || basename.end_with?('.bat')
        end

        # Check if file is executable (Unix) or is a batch file (Windows)
        executables << basename if windows? || File.executable?(bin_path)
      end

      # Discover from binary installations (single metanorma binary)
      # On Windows, look for .exe files
      binary_patterns = [
        File.join(VERSIONS_DIR, '*', 'metanorma'),
        File.join(VERSIONS_DIR, '*', 'metanorma.exe')
      ]

      binary_patterns.each do |pattern|
        Dir.glob(pattern).each do |bin_path|
          # Only if it's a binary installation (has "source" file containing "binary")
          source_file = File.join(File.dirname(bin_path), 'source')
          if File.exist?(source_file) && File.read(source_file).strip == 'binary' && (File.executable?(bin_path) || bin_path.end_with?('.exe'))
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
