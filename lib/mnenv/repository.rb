# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require_relative 'versions_manager'

module Mnenv
  class Repository
    # Default versions manager (shared across all repositories)
    class << self
      def versions_manager
        @versions_manager ||= VersionsManager.new
      end

      attr_writer :versions_manager

      # Force update the versions data
      def update_versions
        versions_manager.update
      end
    end

    attr_reader :data_dir, :versions_file_path

    def initialize(data_dir: nil, update: false)
      @data_dir = data_dir || cli_data_dir || default_data_dir
      @versions_file_path = File.join(@data_dir, 'versions.yaml')
      @versions_cache = {}
      @update = update
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

    def cli_data_dir
      # Check if a data directory was specified via CLI option
      return nil unless defined?(Mnenv::Cli) && Mnenv::Cli.data_dir

      source_dir = Mnenv::Cli.data_dir
      # If the CLI data-dir is specified, use it directly with the source name
      File.join(source_dir, source_name.to_s)
    end

    def default_data_dir
      # Use the versions manager to ensure data is available
      data_path = self.class.versions_manager.ensure_versions_data(update: @update)
      File.join(data_path, source_name.to_s)
    end

    def fetch_versions_data
      return unless File.file?(@versions_file_path)

      YAML.safe_load(File.read(@versions_file_path), permitted_classes: [Time, Symbol, Date])
    rescue StandardError => e
      warn "Warning: Failed to load versions from #{@versions_file_path}: #{e.message}"
      nil
    end
  end
end
