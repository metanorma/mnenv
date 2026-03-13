# frozen_string_literal: true

module Mnenv
  module Snap
    class MissingCredentialsError < StandardError
      def initialize
        super('Missing SNAPCRAFT_STORE_CREDENTIALS environment variable. Please set it to fetch Snap versions.')
      end
    end
  end
end
