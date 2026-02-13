# frozen_string_literal: true

require_relative 'version'

module Mnenv
  class ChocolateyVersion < ArtifactVersion
    attribute :package_name, :string, default: 'metanorma'
    attribute :is_pre_release, :boolean, default: false

    key_value do
      map 'version', to: :version
      map 'published_at', to: :published_at
      map 'parsed_at', to: :parsed_at
      map 'package_name', to: :package_name
      map 'is_pre_release', to: :is_pre_release
    end

    def to_hash
      super.merge(
        'package_name' => package_name,
        'is_pre_release' => is_pre_release
      )
    end
  end
end
