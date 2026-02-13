# frozen_string_literal: true

require_relative '../fetcher'
require_relative '../snap_repository'
require_relative '../models/snap_version'
require_relative '../logger'
require 'uri'
require 'json'
require 'fileutils'
require 'net/http'

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
        # Load existing versions from YAML (single source of truth)
        existing_map = repository.all.to_h { |v| [snap_key(v), v] }

        # Fetch current heads from snap_metadata API
        current_versions = fetch_current_heads

        # Merge: keep existing, add/update current from API
        version_map = {}

        # Add all existing versions
        existing_map.each_value { |v| version_map[snap_key(v)] = v }

        # Add/update current from API (overrides existing if same key)
        current_versions.each do |cv|
          key = snap_key_hash(cv)
          version_map[key] = SnapVersion.new(
            version: cv.fetch('version'),
            revision: cv.fetch('revision'),
            arch: cv.fetch('arch'),
            channel: cv.fetch('channel')
          )
        end

        version_map.values.sort
      end

      private

      def snap_key(version)
        "#{version.version}-#{version.revision}-#{version.arch}-#{version.channel}"
      end

      def snap_key_hash(hash)
        "#{hash.fetch('version')}-#{hash.fetch('revision')}-#{hash.fetch('arch')}-#{hash.fetch('channel')}"
      end

      # Fetch current heads from snap_metadata API for all channel/arch combinations
      def fetch_current_heads
        versions = []

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
              versions << {
                'version' => pkg['version'],
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
