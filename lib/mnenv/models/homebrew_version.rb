# frozen_string_literal: true

require_relative 'version'

module Mnenv
  class HomebrewVersion < ArtifactVersion
    attribute :tag_name, :string
    attribute :commit_sha, :string

    key_value do
      map 'version', to: :version
      map 'published_at', to: :published_at
      map 'parsed_at', to: :parsed_at
      map 'tag_name', to: :tag_name
      map 'commit_sha', to: :commit_sha
    end

    def initialize(*args)
      super
      @tag_name ||= "v#{version}" if version
    end

    def to_hash
      super.merge(
        'tag_name' => tag_name,
        'commit_sha' => commit_sha
      )
    end
  end
end
