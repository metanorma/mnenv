# frozen_string_literal: true

require 'octokit'
require 'yaml'
require_relative 'models/binary_version'

module Mnenv
  # Repository for Binary (packed-mn) GitHub releases
  # Supports both cached YAML data (from versions repo) and live API fallback
  class BinaryRepository
    PACKED_MN_REPO = 'metanorma/packed-mn'

    attr_reader :data_dir

    def initialize(data_dir: nil, update: false)
      @data_dir = data_dir || default_data_dir
      @update = update
      @versions_cache = {}
      load
    end

    # Get all available binary versions
    def all
      # If cache is empty and not loaded from YAML, fall back to live API
      @versions_cache = fetch_from_api if @versions_cache.empty? && !@loaded_from_yaml
      @versions_cache.values.sort.reverse
    end

    # Find a specific version
    def find(version_number)
      version_number = normalize_version(version_number)
      all.find { |v| v.version == version_number }
    end

    # Check if a version is available for the current platform
    def available_for_platform?(version_number)
      version = find(version_number)
      return false unless version

      platform = detect_platform
      binary_name = "metanorma-#{platform}"
      version.assets.any? { |a| a == binary_name || a.include?(platform) }
    end

    # Get the latest version
    def latest
      all.first
    end

    # Count of available versions
    def count
      @versions_cache.size
    end

    private

    # Create Octokit client with GitHub token if available
    # Uses GITHUB_TOKEN (GitHub Actions) or GH_TOKEN (GitHub CLI) for higher rate limits
    # Falls back to unauthenticated client (60 req/hour) if no token is available
    def client
      @client ||= begin
        token = github_token
        if token
          Octokit::Client.new(access_token: token)
        else
          Octokit::Client.new
        end
      end
    end

    # Detect GitHub token from environment variables
    # Priority: GITHUB_TOKEN (GitHub Actions), GH_TOKEN (GitHub CLI)
    def github_token
      ENV['GITHUB_TOKEN'] || ENV['GH_TOKEN']
    end

    def default_data_dir
      # Check if CLI data_dir is specified
      if defined?(Mnenv::Cli) && Mnenv::Cli.data_dir
        File.join(Mnenv::Cli.data_dir, 'binary')
      else
        # Use versions manager to get data path
        require_relative 'versions_manager'
        data_path = Mnenv::Repository.versions_manager.ensure_versions_data(update: @update)
        File.join(data_path, 'binary')
      end
    end

    def load
      versions_file = File.join(@data_dir, 'versions.yaml')

      if File.exist?(versions_file)
        @loaded_from_yaml = true
        data = YAML.safe_load(File.read(versions_file), permitted_classes: [Time, Symbol, Date])
        return unless data && data['versions']

        data['versions'].each do |version_hash|
          version = parse_cached_version(version_hash)
          @versions_cache[version.version] = version if version
        end
      else
        @loaded_from_yaml = false
      end
    rescue StandardError => e
      warn "Warning: Failed to load binary versions from cache: #{e.message}"
      @loaded_from_yaml = false
    end

    def parse_cached_version(hash)
      return nil unless hash['version']

      # Extract assets from platforms array
      assets = (hash['platforms'] || []).map { |p| p['filename'] }

      BinaryVersion.new(
        version: hash['version'],
        display_name: hash['version'],
        published_at: parse_date(hash['published_at']),
        parsed_at: parse_date(hash['parsed_at']),
        metadata: {
          'tag_name' => hash['tag_name'] || "v#{hash['version']}",
          'html_url' => hash['html_url'],
          'assets' => assets
        }
      )
    end

    def fetch_from_api
      releases = fetch_releases
      result = {}
      releases.each do |release|
        version = parse_release(release)
        result[version.version] = version if version
      end
      result
    end

    def fetch_releases
      client.releases(PACKED_MN_REPO)
    rescue Octokit::Error => e
      warn "Warning: Failed to fetch binary releases: #{e.message}"
      []
    end

    def parse_release(release)
      return nil unless release.tag_name =~ /^v(\d+\.\d+\.\d+)/

      version = release.tag_name.sub(/^v/, '')
      published_at = release.published_at

      BinaryVersion.new(
        version: version,
        display_name: version,
        published_at: published_at,
        parsed_at: Time.now.utc,
        metadata: {
          'tag_name' => release.tag_name,
          'html_url' => release.html_url,
          'assets' => release.assets.map(&:name)
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
