# frozen_string_literal: true

require_relative 'version'

module Mnenv
  class GemfileVersion < ArtifactVersion
    attribute :gemfile_exists, :boolean, default: false
    attribute :gemfile_path, :string
    attribute :gemfile_lock_path, :string

    key_value do
      map 'version', to: :version
      map 'published_at', to: :published_at
      map 'parsed_at', to: :parsed_at
      map 'gemfile_exists', to: :gemfile_exists
      map 'gemfile_path', to: :gemfile_path
      map 'gemfile_lock_path', to: :gemfile_lock_path
    end

    def data_dir = @data_dir ||= default_data_dir

    def directory_path = File.join(data_dir, "v#{version}")

    def gemfile_path_calc = File.join(directory_path, 'Gemfile')

    def gemfile_lock_path_calc = File.join(directory_path, 'Gemfile.lock.archived')

    def exists_locally?
      File.directory?(directory_path) &&
        File.file?(gemfile_path_calc) &&
        File.file?(gemfile_lock_path_calc)
    end

    def to_hash
      super.merge(
        'gemfile_exists' => gemfile_exists,
        'gemfile_path' => gemfile_path,
        'gemfile_lock_path' => gemfile_lock_path
      )
    end

    private

    def default_data_dir
      @default_data_dir ||= File.join(__dir__, '..', '..', '..', 'data', 'gemfile')
    end
  end
end
