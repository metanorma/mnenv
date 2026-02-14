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
      regenerate_shims
    end

    def installed?
      Dir.exist?(version_dir)
    end

    private

    def default_target_dir
      @default_target_dir ||= Paths.version_install_dir(version, source)
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

    def regenerate_shims
      ShimManager.new.regenerate_all
    end

    def default_source
      # Try to read from ~/.mnenv/source, else default to gemfile
      if File.exist?(Paths::SOURCE_FILE)
        File.read(Paths::SOURCE_FILE).strip
      else
        'gemfile' # Default: faster for devs
      end
    end
  end
end
