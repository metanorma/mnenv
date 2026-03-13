# frozen_string_literal: true

require_relative 'repository'
require_relative 'models/snap_version'

module Mnenv
  class SnapRepository < Repository
    def version_class = SnapVersion
    def source_name = :snap

    protected

    def load
      data = fetch_versions_data

      return if data.nil? || data['versions'].nil?

      data['versions'].each do |version_hash|
        channels = version_hash['channels'].map do |c|
          SnapChannel.new(
            name: c['name'],
            revision: c['revision'],
            arch: c['arch']
          )
        end

        version = SnapVersion.new.tap do |v|
          v.version = version_hash['version']
          v.published_at = version_hash['published_at']
          v.parsed_at = version_hash['parsed_at']
          v.channels = channels
        end

        cache_version(version)
      end
    end
  end
end
