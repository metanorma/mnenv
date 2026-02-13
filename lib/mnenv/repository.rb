# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require 'open-uri'

module Mnenv
  class Repository
    # Base URL for version data in the metanorma/versions repository
    VERSIONS_BASE_URL = 'https://raw.githubusercontent.com/metanorma/versions/main/data'

    attr_reader :data_dir, :versions_file_path

    def initialize(data_dir: nil)
      @data_dir = data_dir
      @versions_file_path = data_dir ? File.join(data_dir, 'versions.yaml') : nil
      @versions_cache = {}
      load
    end

    def find(version_number) = @versions_cache[version_number]

    def all = @versions_cache.values.sort

    def latest = all.last

    def count = @versions_cache.size

    def exists?(version_number) = @versions_cache.key?(version_number)

    def save(version)
      @versions_cache[version.version] = version
      persist
    end

    def save_all(versions)
      versions.each { |v| @versions_cache[v.version] = v }
      persist
    end

    protected

    def load
      data = fetch_versions_data
      return if data.nil? || data['versions'].nil?

      data['versions'].each do |version_hash|
        version = version_class.new(version_hash)
        cache_version(version)
      end
    end

    # Override in subclasses for custom caching (e.g., SnapRepository uses composite keys)
    def cache_version(version)
      @versions_cache[version.version] = version
    end

    def persist
      return unless @data_dir

      FileUtils.mkdir_p(@data_dir)
      output = {
        'metadata' => metadata,
        'versions' => @versions_cache.values.sort.map(&:to_hash)
      }
      File.write(@versions_file_path, output.to_yaml)
    end

    def metadata
      {
        'generated_at' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
        'source' => source_name,
        'count' => count,
        'latest_version' => latest&.version
      }
    end

    def version_class = raise NotImplementedError

    def source_name = raise NotImplementedError

    private

    def fetch_versions_data
      if @data_dir && File.file?(@versions_file_path)
        # Local mode: read from file
        YAML.safe_load(File.read(@versions_file_path), permitted_classes: [Time, Symbol])
      else
        # Remote mode: fetch from GitHub
        url = "#{VERSIONS_BASE_URL}/#{source_name}/versions.yaml"
        URI.open(url) do |io|
          YAML.safe_load(io.read, permitted_classes: [Time, Symbol])
        end
      end
    rescue OpenURI::HTTPError => e
      warn "Warning: Failed to fetch versions: #{e.message}"
      nil
    end
  end
end
