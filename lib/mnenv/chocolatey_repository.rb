# frozen_string_literal: true

require_relative 'repository'
require_relative 'models/chocolatey_version'

module Mnenv
  class ChocolateyRepository < Repository
    def version_class = ChocolateyVersion
    def source_name = :chocolatey
  end
end
