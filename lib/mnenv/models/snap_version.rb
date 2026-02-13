# frozen_string_literal: true

require_relative 'version'

module Mnenv
  class SnapVersion < ArtifactVersion
    attribute :revision, :integer
    attribute :arch, :string, default: 'amd64'
    attribute :channel, :string, default: 'stable'

    key_value do
      map 'version', to: :version
      map 'published_at', to: :published_at
      map 'parsed_at', to: :parsed_at
      map 'revision', to: :revision
      map 'arch', to: :arch
      map 'channel', to: :channel
    end

    def display_name = revision ? "#{version}-#{revision}" : "v#{version}"

    def to_hash
      super.merge(
        'revision' => revision,
        'arch' => arch,
        'channel' => channel
      )
    end
  end
end
