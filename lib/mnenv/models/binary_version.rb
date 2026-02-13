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

    # Check if binary is available for a specific platform
    def binary_for_platform?(platform)
      assets.any? { |a| a == "metanorma-#{platform}" }
    end
  end
end
