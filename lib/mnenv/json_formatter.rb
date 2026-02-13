# frozen_string_literal: true

require 'json'

module Mnenv
  class JsonFormatter
    def self.format_version(version)
      version.to_hash.merge(
        'display_name' => version.display_name
      ).merge(version_specific_fields(version))
    end

    def self.format_versions(versions)
      {
        'count' => versions.size,
        'latest' => versions.last&.version,
        'versions' => versions.map { |v| format_version(v) }
      }
    end

    class << self
      # Additional fields specific to JSON output format
      def version_specific_fields(version)
        case version
        when GemfileVersion
          { 'gemfile_exists' => version.exists_locally? }
        else
          {}
        end
      end
    end
  end
end
