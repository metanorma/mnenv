# frozen_string_literal: true

require_relative 'version'
require_relative 'snap_channel'

module Mnenv
  class SnapVersion < ArtifactVersion
    attribute :channels, ::Mnenv::SnapChannel,
              collection: true, default: -> { [] }

    key_value do
      map 'channels', to: :channels
    end

    def to_hash
      super.merge(
        'channels' => channels.map(&:to_hash)
      )
    end
  end
end
