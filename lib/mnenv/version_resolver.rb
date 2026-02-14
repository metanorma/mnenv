# frozen_string_literal: true

module Mnenv
  # Centralized version and source resolution with clear precedence:
  # 1. Environment variables (METANORMA_VERSION, METANORMA_SOURCE)
  # 2. Local files (.metanorma-version, .metanorma-source) - walk up tree
  # 3. Global files (~/.mnenv/version, ~/.mnenv/source)
  # 4. Defaults (gemfile for source)
  #
  # This class is the single source of truth for version resolution.
  # The Bash resolver (lib/mnenv/resolver) is kept for shims only.
  class VersionResolver
    # Resolve the current Metanorma version
    # @return [String, nil] The resolved version or nil if not set
    def resolve_version
      from_env('METANORMA_VERSION') ||
        from_local_file('.metanorma-version') ||
        from_global_file(Paths::VERSION_FILE)
    end

    # Resolve the current Metanorma source
    # @return [String] The resolved source (defaults to 'gemfile')
    def resolve_source
      from_env('METANORMA_SOURCE') ||
        from_local_file('.metanorma-source') ||
        from_global_file(Paths::SOURCE_FILE) ||
        'gemfile'
    end

    # Resolve both version and source
    # @return [Array<String, String>] Tuple of [version, source]
    def resolve
      [resolve_version, resolve_source]
    end

    # Check if a version is set anywhere
    # @return [Boolean]
    def version_set?
      !resolve_version.nil?
    end

    # Check if a source is explicitly set (not default)
    # @return [Boolean]
    def source_set?
      from_env('METANORMA_SOURCE') ||
        from_local_file('.metanorma-source') ||
        from_global_file(Paths::SOURCE_FILE)
    end

    # Get the source of version resolution (for debugging)
    # @return [Symbol] :environment, :local, :global, or :none
    def version_source
      return :environment if from_env('METANORMA_VERSION')
      return :local if from_local_file('.metanorma-version')
      return :global if from_global_file(Paths::VERSION_FILE)

      :none
    end

    # Get the source of source resolution (for debugging)
    # @return [Symbol] :environment, :local, :global, or :default
    def source_source
      return :environment if from_env('METANORMA_SOURCE')
      return :local if from_local_file('.metanorma-source')
      return :global if from_global_file(Paths::SOURCE_FILE)

      :default
    end

    private

    # Read from environment variable
    # @param var [String] Environment variable name
    # @return [String, nil] Value or nil if not set/empty
    def from_env(var)
      value = ENV[var]
      value&.strip&.then { |v| v unless v.empty? }
    end

    # Read from local file, walking up directory tree
    # @param filename [String] Filename to look for
    # @return [String, nil] File contents or nil if not found
    def from_local_file(filename)
      dir = Dir.pwd

      loop do
        path = File.join(dir, filename)
        return File.read(path).strip if File.exist?(path)

        parent = File.dirname(dir)
        break if parent == dir # Reached root

        dir = parent
      end

      nil
    end

    # Read from global file
    # @param path [String] Full path to file
    # @return [String, nil] File contents or nil if not found
    def from_global_file(path)
      File.read(path).strip if File.exist?(path)
    rescue StandardError
      nil
    end
  end
end
