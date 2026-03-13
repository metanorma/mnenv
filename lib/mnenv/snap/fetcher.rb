# frozen_string_literal: true

require_relative '../fetcher'
require_relative '../snap_repository'
require_relative '../models/snap_version'
require_relative '../logger'
require 'uri'
require 'json'
require 'fileutils'
require 'net/http'
require_relative 'missing_credentials_error'
require_relative 'snapcraft_not_available_error'
require_relative 'login_failed_error'

module Mnenv
  module Snap
    # Fetches Snap versions from Snapcraft API and merges with historical YAML data.
    # The YAML file (data/snap/versions.yaml) is the single source of truth.
    # Fetcher loads existing YAML, merges with API data, saves back to YAML.
    # Snap cannot support "revamp" as it would lose historical data.
    class Fetcher < Mnenv::Fetcher
      SNAP_NAME = 'metanorma'
      SNAP_ID = 'QkvhpBkFKaDwHMR2LTS3S9Bm0Ek6io11'
      METADATA_API_URL = 'https://api.snapcraft.io/api/v1/snaps/metadata'

      CHANNELS = %w[stable candidate beta edge].freeze
      ARCHITECTURES = %w[amd64 arm64].freeze

      def fetch_all
        fetch_all_from_snapcraft
      end

      def fetch_all_from_cache
        # Load existing versions from YAML
        version_map = repository.all

        # Fetch current heads from snap_metadata API
        current_versions = fetch_current_heads

        current_versions.each_key do |k|
          next if repository.exists?(k)

          # Add new version
          version_map << SnapVersion.new(
            version: k,
            parsed_at: DateTime.now,
            channels: current_versions[k].map do |cv|
              SnapChannel.new(
                name: cv.fetch('channel'),
                revision: cv.fetch('revision'),
                arch: cv.fetch('arch')
              )
            end
          )
        end

        version_map
      end

      def fetch_all_from_snapcraft
        raise MissingCredentialsError unless ENV['SNAPCRAFT_STORE_CREDENTIALS']
        raise SnapcraftNotAvailableError unless snapcraft_available?

        login_result = system('echo "$SNAPCRAFT_STORE_CREDENTIALS" | snapcraft login --with -')

        raise LoginFailedError unless login_result

        # delete the environment variable immediately to prevent
        # duplicate login error
        ENV.delete('SNAPCRAFT_STORE_CREDENTIALS')

        result = `snapcraft revisions metanorma`
        snap_revisions = parse_snap_revisions(result)
        build_snap_version_map(snap_revisions)
      end

      private

      def snapcraft_available?
        system('command -v snapcraft > /dev/null 2>&1')
      end

      def parse_snap_revisions(data)
        lines = data.lines.map(&:strip).reject { |l| l.empty? || l.start_with?('Rev.') }
        revisions = []
        lines.each do |line|
          fields = line.split(/\s{2,}/)
          rev, uploaded, arches, version, channels = fields
          revisions << {
            version: version,
            published_at: uploaded,
            revision: rev,
            arch: arches,
            channels: channels
          }
        end
        revisions
      end

      def build_snap_version_map(snap_revisions)
        versions = []
        latest_version = snap_revisions.first[:version]

        snap_revisions.each do |sr|
          snap_version = versions.find { |v| v&.version == sr[:version] }
          if snap_version.nil?
            snap_version = SnapVersion.new
            snap_version.version = sr[:version]
            snap_version.published_at = sr[:published_at]
            snap_version.parsed_at = DateTime.now
          end

          channels = sr[:channels].split(',').map(&:strip)
          channels.each do |channel|
            next unless channel.start_with? 'latest/'

            channel = channel.sub('latest/', '')
            next if (sr[:version] == latest_version) && !channel.end_with?('*')

            snap_version.channels << SnapChannel.new(
              name: channel.gsub('*', ''),
              revision: sr[:revision],
              arch: sr[:arch]
            )
          end

          versions << snap_version
        end

        versions.reverse
      end

      # Fetch current heads from snap_metadata API for all channel/arch combinations
      def fetch_current_heads
        versions = {}

        CHANNELS.each do |channel|
          ARCHITECTURES.each do |arch|
            body = {
              snaps: [{
                snap_id: SNAP_ID,
                channel: channel,
                architecture: arch
              }],
              fields: %w[version revision channel architecture download_url]
            }

            uri = URI(METADATA_API_URL)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            request = Net::HTTP::Post.new(uri.path)
            request['Content-Type'] = 'application/json'
            request['X-Ubuntu-Series'] = '16'
            request.body = body.to_json

            response = http.request(request)
            data = JSON.parse(response.body)

            if data['_embedded'] && data['_embedded']['clickindex:package']
              pkg = data['_embedded']['clickindex:package'][0]

              versions[pkg['version']] ||= []
              versions[pkg['version']] << {
                'revision' => pkg['revision'],
                'arch' => arch,
                'channel' => channel
              }
            end
          rescue StandardError => e
            Logger.warning "Failed to fetch #{channel}/#{arch}: #{e.message}"
          end
        end

        versions
      end

      def default_repository = @default_repository ||= SnapRepository.new
    end
  end
end
