# frozen_string_literal: true

module Mnenv
  class ArtifactVersion < Lutaml::Model::Serializable
    attribute :version, :string
    attribute :published_at, :date_time
    attribute :parsed_at, :date_time

    key_value do
      map 'version', to: :version
      map 'published_at', to: :published_at
      map 'parsed_at', to: :parsed_at
    end

    def <=>(other) = version_parts <=> other.version_parts

    def display_name = "v#{version}"

    # Serialize version to hash for persistence
    # Subclasses should override and merge with super
    def to_hash
      {
        'version' => version,
        'published_at' => format_timestamp(published_at),
        'parsed_at' => format_timestamp(parsed_at)
      }
    end

    private

    def format_timestamp(time)
      time&.strftime('%Y-%m-%dT%H:%M:%SZ')
    end

    protected

    def version_parts = version.split('.').map(&:to_i)
  end
end
