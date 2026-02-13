# frozen_string_literal: true

module Mnenv
  class Installer
    class InstallationError < StandardError; end
    class DevelopmentToolsMissing < InstallationError; end

    attr_reader :version, :source

    def initialize(version, source: nil, target_dir: nil)
      @version = version
      @source = source || default_source
      @target_dir = target_dir || default_target_dir
    end

    def install
      verify_prerequisites!
      create_install_directory
      perform_installation
      save_source_metadata
      regenerate_shims
    end

    def installed?
      Dir.exist?(version_dir)
    end

    private

    def default_target_dir
      @default_target_dir ||= File.expand_path("~/.mnenv/versions/#{version}")
    end

    def version_dir
      @target_dir
    end

    def verify_prerequisites!
      raise NotImplementedError, "#{self.class} must implement verify_prerequisites!"
    end

    def perform_installation
      raise NotImplementedError, "#{self.class} must implement perform_installation!"
    end

    def create_install_directory
      FileUtils.mkdir_p(version_dir)
    end

    def save_source_metadata
      File.write(File.join(version_dir, 'source'), @source)
    end

    def regenerate_shims
      ShimManager.new.regenerate_all
    end

    def default_source
      # Try to read from ~/.mnenv/source, else default to gemfile
      global_source_file = File.expand_path('~/.mnenv/source')
      if File.exist?(global_source_file)
        File.read(global_source_file).strip
      else
        'gemfile' # Default: faster for devs
      end
    end
  end
end
