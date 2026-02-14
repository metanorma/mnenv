# frozen_string_literal: true

require_relative 'source_registry'
require_relative 'gemfile_repository'
require_relative 'binary_repository'
require_relative 'models/gemfile_version'
require_relative 'models/binary_version'
require_relative 'installers/gemfile_installer'
require_relative 'installers/binary_installer'

module Mnenv
  # Auto-registration of built-in sources
  # This enables the plugin architecture - new sources just need to register themselves
  module Sources
    class << self
      # Register all built-in sources
      def setup
        register_gemfile
        register_binary
      end

      private

      def register_gemfile
        SourceRegistry.register(
          name: 'gemfile',
          repository: GemfileRepository,
          model: GemfileVersion,
          installer: Installers::GemfileInstaller
        )
      end

      def register_binary
        SourceRegistry.register(
          name: 'binary',
          repository: BinaryRepository,
          model: BinaryVersion,
          installer: Installers::BinaryInstaller
        )
      end
    end
  end
end

# Auto-setup on load
Mnenv::Sources.setup
