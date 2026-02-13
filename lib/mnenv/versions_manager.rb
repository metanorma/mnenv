# frozen_string_literal: true

require 'fileutils'
require 'git'

module Mnenv
  # Manages the local clone of the metanorma/versions repository
  # Similar to how Homebrew manages its core tap
  class VersionsManager
    VERSIONS_REPO = 'https://github.com/metanorma/versions.git'
    DEFAULT_MNENV_DIR = File.expand_path('~/.mnenv')
    VERSIONS_DIR = 'versions'

    attr_reader :mnenv_dir, :versions_path

    def initialize(mnenv_dir: nil)
      @mnenv_dir = mnenv_dir || DEFAULT_MNENV_DIR
      @versions_path = File.join(@mnenv_dir, VERSIONS_DIR)
    end

    # Ensure versions repository is cloned and up to date
    # @param update [Boolean] Force update (git fetch) even if already cloned
    # @return [String] Path to the versions data directory
    def ensure_versions_data(update: false)
      if cloned?
        update_clone if update || stale?
      else
        clone_repo
      end

      data_path
    end

    # Check if versions repository is cloned
    def cloned?
      File.directory?(File.join(versions_path, '.git'))
    end

    # Check if the clone is stale (older than 24 hours)
    def stale?
      return true unless cloned?

      last_update_file = File.join(versions_path, '.mnenv_last_update')
      return true unless File.exist?(last_update_file)

      last_update = File.mtime(last_update_file)
      Time.now - last_update > 86_400 # 24 hours
    end

    # Path to the data directory within the versions repository
    def data_path
      File.join(versions_path, 'data')
    end

    # Clone the versions repository using the git gem
    def clone_repo
      FileUtils.mkdir_p(mnenv_dir)
      Git.clone(VERSIONS_REPO, VERSIONS_DIR, path: mnenv_dir, depth: 1)
      touch_update_marker
    rescue Git::GitExecuteError => e
      raise "Failed to clone versions repository: #{e.message}"
    end

    # Update the versions repository using the git gem
    def update_clone
      return unless cloned?

      g = Git.open(versions_path)
      g.fetch
      g.reset_hard('origin/main')
      touch_update_marker
    rescue Git::GitExecuteError => e
      warn "Warning: Failed to update versions repository: #{e.message}"
    end

    # Force update the versions repository
    def update
      if cloned?
        update_clone
      else
        clone_repo
      end
      data_path
    end

    private

    def touch_update_marker
      FileUtils.touch(File.join(versions_path, '.mnenv_last_update'))
    end
  end
end
