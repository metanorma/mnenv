# frozen_string_literal: true

module Mnenv
  # Centralized directory paths for mnenv
  # This ensures consistency across all components
  module Paths
    # Base directory for all mnenv data
    MNENV_DIR = File.expand_path('~/.mnenv').freeze

    # Directory for the git clone of metanorma/versions (READ-ONLY data)
    # Contains: data/gemfile/versions.yaml, data/gemfile/v1.14.4/Gemfile, etc.
    VERSIONS_DATA_DIR = File.join(MNENV_DIR, 'versions').freeze

    # Directory for installed Metanorma versions
    # Contains: 1.14.3/, 1.14.4/, etc. (each with bin/, source, etc.)
    INSTALLED_DIR = File.join(MNENV_DIR, 'installed').freeze

    # Directory for shim scripts
    SHIMS_DIR = File.join(MNENV_DIR, 'shims').freeze

    # Directory for mnenv library files (resolver, etc.)
    LIB_DIR = File.join(MNENV_DIR, 'lib', 'mnenv').freeze

    # Global version file
    VERSION_FILE = File.join(MNENV_DIR, 'version').freeze

    # Global source file
    SOURCE_FILE = File.join(MNENV_DIR, 'source').freeze

    class << self
      # Ensure all required directories exist
      def ensure_directories
        FileUtils.mkdir_p(MNENV_DIR)
        FileUtils.mkdir_p(INSTALLED_DIR)
        FileUtils.mkdir_p(SHIMS_DIR)
        FileUtils.mkdir_p(LIB_DIR)
      end

      # Get the installation directory for a specific version
      def version_install_dir(version)
        File.join(INSTALLED_DIR, version)
      end

      # Get the path to the data directory within the versions repo
      def versions_data_path
        File.join(VERSIONS_DATA_DIR, 'data')
      end
    end
  end
end
