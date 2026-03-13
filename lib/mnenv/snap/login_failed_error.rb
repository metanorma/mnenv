# frozen_string_literal: true

module Mnenv
  module Snap
    class LoginFailedError < StandardError
      def initialize
        super('Failed to login to snapcraft with provided credentials.')
      end
    end
  end
end
