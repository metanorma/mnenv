# frozen_string_literal: true

require_relative 'version'
require_relative 'release_provenance'
require_relative '../versions_manager'

module Mnenv
  class GemfileVersion < ArtifactVersion
    attribute :gemfile_exists, :boolean, default: false
    attribute :gemfile_path, :string
    attribute :gemfile_lock_path, :string
    # Optional provenance (metanorma/ci#367) — parsed and re-emitted so the
    # daily refresh round-trips instead of dropping them.
    attribute :rubygems_created_at, :date_time
    attribute :release_provenance, ReleaseProvenance

    # Class-level versions manager for dependency injection in tests
    class << self
      def versions_manager
        @versions_manager ||= VersionsManager.new
      end

      attr_writer :versions_manager
    end

    key_value do
      map 'version', to: :version
      map 'published_at', to: :published_at
      map 'parsed_at', to: :parsed_at
      map 'gemfile_exists', to: :gemfile_exists
      map 'gemfile_path', to: :gemfile_path
      map 'gemfile_lock_path', to: :gemfile_lock_path
      map 'rubygems_created_at', to: :rubygems_created_at
      map 'release_provenance', to: :release_provenance
    end

    def data_dir
      @data_dir ||= begin
        base_dir = if defined?(Mnenv::Cli) && Mnenv::Cli.data_dir
                     Mnenv::Cli.data_dir
                   else
                     self.class.versions_manager.data_path
                   end
        File.join(base_dir, 'gemfile')
      end
    end

    def directory_path = File.join(data_dir, "v#{version}")

    def gemfile_path_calc = File.join(directory_path, 'Gemfile')

    def gemfile_lock_path_calc = File.join(directory_path, 'Gemfile.lock.archived')

    def exists_locally?
      File.directory?(directory_path) &&
        File.file?(gemfile_path_calc) &&
        File.file?(gemfile_lock_path_calc)
    end

    def to_hash
      h = super.merge(
        'gemfile_exists' => gemfile_exists,
        'gemfile_path' => gemfile_path,
        'gemfile_lock_path' => gemfile_lock_path
      )
      h['rubygems_created_at'] = format_timestamp(rubygems_created_at) if rubygems_created_at
      h['release_provenance'] = release_provenance.to_hash if release_provenance
      h
    end
  end
end
