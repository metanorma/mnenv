# frozen_string_literal: true

module Mnenv
  module Snap
    class SnapcraftNotAvailableError < StandardError
      def initialize
        super('Snapcraft is not available. Please install Snapcraft to fetch Snap versions.')
      end
    end
  end
end
