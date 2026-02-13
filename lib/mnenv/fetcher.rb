# frozen_string_literal: true

require 'json'
require 'open-uri'

module Mnenv
  class Fetcher
    attr_reader :repository

    def initialize(repository: nil)
      @repository = repository || default_repository
    end

    def fetch_all
      raise NotImplementedError
    end

    def fetch_and_save
      versions = fetch_all
      repository.save_all(versions)
      versions
    end

    protected

    def fetch_json(uri) = JSON.parse(URI(uri).open.read)

    def default_repository = raise NotImplementedError
  end
end
