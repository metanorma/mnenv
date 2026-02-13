# frozen_string_literal: true

require 'octokit'

module Mnenv
  module Binary
    # Fetches binary release information from GitHub packed-mn repository
    class Fetcher
      PACKED_MN_REPO = 'metanorma/packed-mn'

      # Fetch all releases from GitHub API
      # @return [Array<Hash>] Array of release data hashes
      def fetch_all
        releases = client.releases(PACKED_MN_REPO)
        releases.map { |release| parse_release(release) }.compact
      end

      # Fetch a single release by tag
      # @param tag [String] The tag name (e.g., "v1.14.4")
      # @return [Hash, nil] Release data hash or nil if not found
      def fetch_by_tag(tag)
        release = client.release_by_tag(PACKED_MN_REPO, tag)
        parse_release(release)
      rescue Octokit::NotFound
        nil
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

      def parse_release(release)
        return nil unless release.tag_name =~ /^v(\d+\.\d+\.\d+)/

        version = release.tag_name.sub(/^v/, '')
        published_at = release.published_at

        {
          'version' => version,
          'published_at' => published_at&.utc&.strftime('%Y-%m-%dT%H:%M:%SZ'),
          'parsed_at' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
          'tag_name' => release.tag_name,
          'html_url' => release.html_url,
          'platforms' => parse_platforms(release.assets)
        }
      end

      def parse_platforms(assets)
        assets.map do |asset|
          name = asset.name
          platform = parse_asset_name(name)
          next nil unless platform

          {
            'name' => platform[:os],
            'arch' => platform[:arch],
            'variant' => platform[:variant],
            'format' => platform[:format],
            'filename' => name,
            'url' => asset.browser_download_url,
            'size' => asset.size
          }.compact
        end.compact
      end

      # Parse asset filename to extract platform info
      # Examples:
      #   metanorma-darwin-arm64.tgz -> { os: 'darwin', arch: 'arm64', format: 'tgz' }
      #   metanorma-linux-x86_64.tgz -> { os: 'linux', arch: 'x86_64', format: 'tgz' }
      #   metanorma-linux-musl-x86_64.tgz -> { os: 'linux', arch: 'x86_64', variant: 'musl', format: 'tgz' }
      #   metanorma-windows-x86_64.exe -> { os: 'windows', arch: 'x86_64', format: 'exe' }
      #   metanorma-windows-x86_64.zip -> { os: 'windows', arch: 'x86_64', format: 'zip' }
      def parse_asset_name(name)
        return nil unless name =~ /^metanorma-(.+)/

        parts = Regexp.last_match(1).split('.')
        basename = parts.first
        format = parts.last

        # Parse basename: darwin-arm64, linux-x86_64, linux-musl-x86_64, windows-x86_64
        components = basename.split('-')

        # Skip non-binary assets (e.g., .sha256.txt files)
        return nil unless %w[tgz zip exe].include?(format)

        case components
        in ['darwin', arch]
          { os: 'darwin', arch: arch, format: format }
        in ['linux', 'musl', arch]
          { os: 'linux', arch: arch, variant: 'musl', format: format }
        in ['linux', arch]
          { os: 'linux', arch: arch, format: format }
        in ['windows', arch]
          { os: 'windows', arch: arch, format: format }
        in ['macos', arch]
          # Legacy naming: metanorma-macos-arm64.tgz
          { os: 'darwin', arch: arch, format: format }
        else
          # Unknown format, try to extract what we can
          os = components.first
          arch = components.last
          { os: os, arch: arch, format: format }
        end
      end
    end
  end
end
