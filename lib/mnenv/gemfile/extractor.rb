# frozen_string_literal: true

require 'English'
require_relative '../logger'
require_relative '../gemfile_repository'
require_relative './fetcher'
require_relative '../models/gemfile_version'
require 'fileutils'

module Mnenv
  module Gemfile
    class Extractor
      ExtractionMode = %i[incremental replace revamp].freeze

      attr_reader :mode, :repository, :fetcher, :target_version

      def initialize(mode: :incremental, repository: nil, fetcher: nil, target_version: nil)
        @mode = mode || :incremental
        @repository = repository || GemfileRepository.new
        @fetcher = fetcher || Fetcher.new(repository: @repository)
        @target_version = target_version
      end

      def run
        Logger.header "Starting Gemfile extraction (mode: #{mode})"

        case mode
        when :incremental then extract_incremental
        when :replace then extract_replace
        when :revamp then extract_revamp
        end

        Logger.success 'Extraction complete'
      end

      private

      def extract_incremental
        remote_versions = fetcher.fetch_all
        existing_versions = repository.all.select(&:exists_locally?).map(&:version)

        missing = remote_versions.reject { |v| existing_versions.include?(v.version) }

        Logger.info "Found #{missing.size} new versions"

        missing.each { |v| extract_version(v) }
      end

      def extract_replace
        raise 'target_version required for replace mode' unless target_version

        remote_version = fetcher.fetch_all.find { |v| v.version == target_version }
        raise "Version #{target_version} not found remotely" unless remote_version

        local_version = repository.find(target_version)
        remove_gemfiles(local_version) if local_version

        extract_version(remote_version)
      end

      def extract_revamp
        remote_versions = fetcher.fetch_all

        Logger.info "Re-extracting #{remote_versions.size} versions"

        remote_versions.each { |v| extract_version(v) }
      end

      def extract_version(version)
        Logger.pulling version.version
        pull_docker_image(version.version)

        Logger.section "Extracting Gemfiles from #{version.version}"
        extract_gemfiles(version)

        cleanup_docker_image(version.version)

        # Update version metadata after successful extraction
        version.gemfile_exists = true
        # Store relative paths (relative to data/gemfile directory)
        version.gemfile_path = "v#{version.version}/Gemfile"
        version.gemfile_lock_path = "v#{version.version}/Gemfile.lock.archived"

        repository.save(version)
      end

      def pull_docker_image(version_number)
        system('docker', 'pull', "#{Fetcher::DOCKER_IMAGE}:#{version_number}", out: File::NULL)
        raise 'Failed to pull Docker image' unless $CHILD_STATUS.success?
      end

      def extract_gemfiles(version)
        FileUtils.mkdir_p(version.directory_path)

        script = gemfile_extraction_script
        cmd = "docker run --rm --entrypoint sh #{Fetcher::DOCKER_IMAGE}:#{version.version} -c '#{script}'"
        output = `#{cmd}`

        raise "Extraction failed for #{version.version}" unless $CHILD_STATUS.success?

        gemfile, gemfile_lock = parse_gemfile_output(output)

        File.write(version.gemfile_path_calc, gemfile)
        File.write(version.gemfile_lock_path_calc, gemfile_lock)

        Logger.extracted version.version
      end

      def gemfile_extraction_script
        <<~SCRIPT
          for path in /metanorma/Gemfile /setup/Gemfile /Gemfile /root/Gemfile; do
            if [ -f "$path" ]; then
              gemfile_dir=$(dirname "$path")
              echo "GEMFILE_DIR=$gemfile_dir"
              cat "$path"
              echo "===GEMFILE.EOF==="
              cat "$gemfile_dir/Gemfile.lock"
              exit 0
            fi
          done
          echo "ERROR: No Gemfile found"
          exit 1
        SCRIPT
      end

      def parse_gemfile_output(output)
        parts = output.split('===GEMFILE.EOF===')
        raise 'Failed to parse output' if parts.size < 2

        gemfile = parts[0].sub(/GEMFILE_DIR=.+\n/, '')
        gemfile_lock = parts[1]

        [gemfile.strip, gemfile_lock.strip]
      end

      def remove_gemfiles(version)
        FileUtils.rm_f([version.gemfile_path_calc, version.gemfile_lock_path_calc])
        Logger.info "Removed existing Gemfiles for #{version.version}"
      end

      def cleanup_docker_image(version_number)
        system('docker', 'rmi', '-f', "#{Fetcher::DOCKER_IMAGE}:#{version_number}",
               out: File::NULL, err: File::NULL)
      end
    end
  end
end
