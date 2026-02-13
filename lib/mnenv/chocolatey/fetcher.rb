# frozen_string_literal: true

require_relative '../fetcher'
require_relative '../chocolatey_repository'
require_relative '../models/chocolatey_version'
require 'nokogiri'
require 'uri'

module Mnenv
  module Chocolatey
    class Fetcher < Mnenv::Fetcher
      API_URL = 'https://community.chocolatey.org/api/v2'
      PACKAGE_NAME = 'metanorma'

      def fetch_all
        # Use OData v2 Packages endpoint with filter
        # Note: Use pre-encoded URL to avoid encoding issues
        search_url = "#{API_URL}/Packages()?%24filter=Id%20eq%20'#{PACKAGE_NAME}'"

        versions = []
        loop do
          uri = URI(search_url)
          xml_content = uri.open.read
          doc = Nokogiri::XML(xml_content)

          # Parse Atom feed entries using wildcard namespace
          doc.xpath('//*:entry').each do |entry|
            # Get properties using wildcard
            properties = entry.at_xpath('.//*:properties')
            next unless properties

            version_elem = properties.at_xpath('./*:Version')
            next unless version_elem

            version_string = version_elem.content&.strip
            next if version_string.empty?

            # Get IsPrerelease
            prerelease_elem = properties.at_xpath('./*:IsPrerelease')
            is_prerelease = prerelease_elem&.content == 'true'

            versions << ChocolateyVersion.new(
              version: version_string,
              package_name: PACKAGE_NAME,
              is_pre_release: is_prerelease
            )
          end

          # Check for next page link
          next_link = doc.at_xpath('//*:link[@rel="next"]')
          break unless next_link

          search_url = next_link['href']
          break unless search_url

          # Make relative URLs absolute and upgrade http to https
          search_url = search_url.start_with?('http') ? search_url : "#{API_URL}/#{search_url}"
          search_url = search_url.sub('http://', 'https://')
        end

        versions.sort_by(&:version)
      end

      private

      def default_repository = @default_repository ||= ChocolateyRepository.new
    end
  end
end
