# frozen_string_literal: true

require_relative 'repository'
require_relative 'models/homebrew_version'

module Mnenv
  class HomebrewRepository < Repository
    def version_class = HomebrewVersion
    def source_name = :homebrew
  end
end
