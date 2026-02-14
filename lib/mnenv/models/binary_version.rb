# frozen_string_literal: true

require_relative 'version'

module Mnenv
  class BinaryVersion < ArtifactVersion
    attribute :metadata, :hash, default: {}

    key_value do
      map 'version', to: :version
      map 'published_at', to: :published_at
      map 'parsed_at', to: :parsed_at
      map 'metadata', to: :metadata
    end

    # Binary versions use plain version display (no 'v' prefix)
    def display_name = version

    # Get the release tag name (with 'v' prefix)
    def tag_name = "v#{version}"

    # Get the GitHub release URL
    def html_url
      metadata&.dig('html_url')
    end

    # Get list of available assets for this release
    def assets
      metadata&.dig('assets') || []
    end

    # Get platforms info (with URLs, format, etc.)
    def platforms
      metadata&.dig('platforms') || []
    end

    # Check if binary is available for a specific platform
    def binary_for_platform?(platform)
      assets.any? { |a| a == "metanorma-#{platform}" }
    end

    # Find the best matching platform entry for current system
    # Returns the platform hash with url, format, etc.
    def find_platform(name:, arch:, variant: nil, format: nil)
      candidates = platforms.select { |p| p['name'] == name && p['arch'] == arch }

      # Filter by variant
      # - If variant is specified, match platforms with that variant
      # - If variant is nil, match platforms WITHOUT a variant (glibc, not musl)
      candidates = if variant
                     candidates.select { |p| p['variant'] == variant }
                   else
                     candidates.select { |p| p['variant'].nil? }
                   end

      # Filter by format if specified
      if format
        candidates = candidates.select { |p| p['format'] == format }
      end

      candidates.first
    end

    # Get download URL for a specific platform/arch combination
    def download_url(name:, arch:, variant: nil, format: nil)
      platform = find_platform(name: name, arch: arch, variant: variant, format: format)
      platform&.dig('url')
    end

    # Get available platform names
    def available_platforms
      platforms.map { |p| p['name'] }.uniq
    end

    # Get available architectures for a platform
    def available_arches_for(platform_name)
      platforms.select { |p| p['name'] == platform_name }.map { |p| p['arch'] }.uniq
    end
  end
end
