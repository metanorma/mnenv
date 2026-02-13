# frozen_string_literal: true

module Mnenv
  # Registry for version sources (gemfile, binary, snap, homebrew, chocolatey)
  # Enables plugin architecture - new sources just need to register themselves
  class SourceRegistry
    class DuplicateSourceError < StandardError; end
    class UnknownSourceError < StandardError; end

    # Register a new source
    # @param name [String] the source identifier (e.g., 'gemfile', 'binary')
    # @param repository [Class] the repository class for this source
    # @param model [Class] the version model class for this source
    # @param installer [Class, nil] the installer class (optional)
    def self.register(name:, repository:, model:, installer: nil)
      name = name.to_s
      raise DuplicateSourceError, "Source '#{name}' is already registered" if sources.key?(name)

      sources[name] = {
        repository: repository,
        model: model,
        installer: installer
      }
    end

    # Get repository class for a source
    def self.repository(name)
      source = sources[name.to_s]
      raise UnknownSourceError, "Unknown source: #{name}" unless source

      source[:repository]
    end

    # Get model class for a source
    def self.model(name)
      source = sources[name.to_s]
      raise UnknownSourceError, "Unknown source: #{name}" unless source

      source[:model]
    end

    # Get installer class for a source
    def self.installer(name)
      source = sources[name.to_s]
      raise UnknownSourceError, "Unknown source: #{name}" unless source

      source[:installer]
    end

    # Get all registered source names
    def self.all_names
      sources.keys.sort
    end

    # Check if a source is registered
    def self.registered?(name)
      sources.key?(name.to_s)
    end

    # Clear all registrations (useful for testing)
    def self.clear
      @sources = nil
    end

    def self.sources
      @sources ||= {}
    end
  end
end
