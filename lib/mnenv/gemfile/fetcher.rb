# frozen_string_literal: true

require_relative '../fetcher'
require_relative '../gemfile_repository'
require_relative '../models/gemfile_version'

module Mnenv
  module Gemfile
    class Fetcher < Mnenv::Fetcher
      DOCKER_IMAGE = 'metanorma/metanorma'
      API_BASE = "https://registry.hub.docker.com/v2/repositories/#{DOCKER_IMAGE}/tags".freeze

      def fetch_all
        uri = URI("#{API_BASE}?page_size=100")
        versions = []

        loop do
          data = fetch_json(uri)
          data['results'].each do |result|
            name = result['name']
            next unless name.match?(/^\d+\.\d+\.\d+$/)

            versions << GemfileVersion.new(
              version: name,
              published_at: parse_timestamp(result['tag_last_pushed'])
            )
          end
          break unless data['next']

          uri = URI(data['next'])
        end

        versions.sort
      end

      private

      def parse_timestamp(value) = value&.then { |v| Time.parse(v) }

      def default_repository = @default_repository ||= GemfileRepository.new
    end
  end
end
