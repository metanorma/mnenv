# frozen_string_literal: true

require_relative 'repository'
require_relative 'models/gemfile_version'

module Mnenv
  class GemfileRepository < Repository
    def version_class = GemfileVersion
    def source_name = :gemfile
  end
end
