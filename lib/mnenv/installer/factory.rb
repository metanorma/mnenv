# frozen_string_literal: true

require_relative '../source_registry'

module Mnenv
  # Factory for creating installer instances based on source type
  # Uses SourceRegistry for extensibility - new sources just need to register
  class InstallerFactory
    class UnknownSourceError < StandardError; end

    # Create an installer for the given version and source
    # @param version [String] The version to install
    # @param source [String] The source type (e.g., 'gemfile', 'binary')
    # @param target_dir [String, nil] Optional custom target directory
    # @return [Installer] An installer instance
    # @raise [UnknownSourceError] If source is not registered
    def self.create(version, source:, target_dir: nil)
      installer_class = SourceRegistry.installer(source.to_s)

      unless installer_class
        available = SourceRegistry.all_names.join(', ')
        raise Installer::InstallationError,
              "Unknown source: #{source}. Available sources: #{available}"
      end

      installer_class.new(version, source: source, target_dir: target_dir)
    rescue SourceRegistry::UnknownSourceError
      available = SourceRegistry.all_names.join(', ')
      raise Installer::InstallationError,
            "Unknown source: #{source}. Available sources: #{available}"
    end

    # Check if a source is supported
    # @param source [String] The source type
    # @return [Boolean]
    def self.supported?(source)
      SourceRegistry.registered?(source.to_s)
    end

    # Get list of supported sources
    # @return [Array<String>]
    def self.supported_sources
      SourceRegistry.all_names
    end
  end
end
