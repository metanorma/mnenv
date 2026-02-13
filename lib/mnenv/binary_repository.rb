# frozen_string_literal: true

require 'open-uri'
require 'json'
require_relative 'models/binary_version'

module Mnenv
  # Repository for Binary (packed-mn) GitHub releases
  # Note: This does not inherit from Repository because it fetches live data
  # from GitHub API rather than using cached YAML files.
  class BinaryRepository
    PACKED_MN_REPO = 'metanorma/packed-mn'
    RELEASES_URL = "https://api.github.com/repos/#{PACKED_MN_REPO}/releases".freeze

    # Get all available binary versions from GitHub releases
    def all
      @all ||= begin
        releases = fetch_releases
        releases.map do |release|
          parse_release(release)
        end.compact.sort.reverse
      end
    end

    # Find a specific version
    def find(version_number)
      version_number = normalize_version(version_number)
      all.find { |v| v.version == version_number }
    end

    # Check if a version is available for the current platform
    def available_for_platform?(version_number)
      release = fetch_release_by_tag("v#{version_number}")
      return false unless release

      platform = detect_platform
      binary_name = "metanorma-#{platform}"
      release['assets'].any? { |asset| asset['name'] == binary_name }
    end

    # Get the latest version
    def latest
      all.first
    end

    private

    def fetch_releases
      URI.open(RELEASES_URL, 'Accept' => 'application/vnd.github.v3+json') do |io|
        JSON.parse(io.read)
      end
    rescue OpenURI::HTTPError => e
      warn "Warning: Failed to fetch binary releases: #{e.message}"
      []
    end

    def fetch_release_by_tag(tag)
      url = "https://api.github.com/repos/#{PACKED_MN_REPO}/releases/tags/#{tag}"
      URI.open(url, 'Accept' => 'application/vnd.github.v3+json') do |io|
        JSON.parse(io.read)
      end
    rescue OpenURI::HTTPError
      nil
    end

    def parse_release(release)
      return nil unless release['tag_name'] =~ /^v(\d+\.\d+\.\d+)/

      version = release['tag_name'].sub(/^v/, '')
      published_at = parse_date(release['published_at'])

      BinaryVersion.new(
        version: version,
        display_name: version,
        published_at: published_at,
        parsed_at: Time.now.utc,
        metadata: {
          'tag_name' => release['tag_name'],
          'html_url' => release['html_url'],
          'assets' => release['assets'].map { |a| a['name'] }
        }
      )
    end

    def parse_date(date_string)
      return nil unless date_string

      Time.parse(date_string)
    rescue ArgumentError
      nil
    end

    def detect_platform
      case RbConfig::CONFIG['host_os']
      when /linux/   then 'linux'
      when /darwin/  then 'macos'
      when /mswin|mingw|cygwin/ then 'windows'
      else 'unknown'
      end
    end

    def normalize_version(version)
      version.sub(/^v/, '')
    end
  end
end
