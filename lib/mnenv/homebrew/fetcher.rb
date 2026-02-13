# frozen_string_literal: true

require_relative '../fetcher'
require_relative '../homebrew_repository'
require_relative '../models/homebrew_version'

module Mnenv
  module Homebrew
    class Fetcher < Mnenv::Fetcher
      GITHUB_REPO = 'metanorma/homebrew-metanorma'
      API_URL = "https://api.github.com/repos/#{GITHUB_REPO}/tags".freeze

      def fetch_all
        uri = URI("#{API_URL}?per_page=100")
        versions = []
        page = 0

        loop do
          data = fetch_json(uri)
          data.each do |tag|
            name = tag['name']
            next unless name.match?(/^v\d+\.\d+\.\d+$/)

            versions << HomebrewVersion.new(
              version: name.sub(/^v/, ''),
              tag_name: name,
              commit_sha: tag['commit']['sha']
            )
          end

          page += 1
          uri = URI("#{API_URL}?per_page=100&page=#{page}")
          break if data.empty?
        end

        versions.sort
      end

      private

      def default_repository = @default_repository ||= HomebrewRepository.new
    end
  end
end
