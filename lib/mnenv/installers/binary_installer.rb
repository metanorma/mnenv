# frozen_string_literal: true

require 'open-uri'
require 'json'
require_relative '../installer/base'

module Mnenv
  module Installers
    class BinaryInstaller < Installer
      PACKED_MN_REPO = 'metanorma/packed-mn'
      RELEASES_URL = "https://api.github.com/repos/#{PACKED_MN_REPO}/releases".freeze

      def verify_prerequisites!
        verify_version_available!
      end

      def perform_installation
        download_binary
        make_executable
      end

      private

      def verify_version_available!
        releases = fetch_releases
        tag_name = "v#{version}"

        return if releases.any? { |r| r['tag_name'] == tag_name }

        available = releases.map { |r| r['tag_name'] }.join(', ')
        raise InstallationError, "Binary version #{version} not found.\n" \
                                "Available: #{available}\n" \
                                "Or use: mnenv install #{version} --source=gemfile"
      end

      def download_binary
        url = binary_url
        warn "Downloading #{url}..."

        URI(url).open do |io|
          File.write(File.join(version_dir, 'metanorma'), io.read)
        end
      rescue OpenURI::HTTPError => e
        raise InstallationError, "Failed to download binary: #{e.message}"
      end

      def make_executable
        binary_path = File.join(version_dir, 'metanorma')
        File.chmod(0o755, binary_path)
      end

      def binary_url
        platform = detect_platform
        tag_name = "v#{version}"
        "https://github.com/#{PACKED_MN_REPO}/releases/download/#{tag_name}/metanorma-#{platform}"
      end

      def detect_platform
        case RbConfig::CONFIG['host_os']
        when /linux/   then 'linux'
        when /darwin/  then 'macos'
        when /mswin|mingw|cygwin/ then 'windows'
        else raise InstallationError, 'Unsupported platform for binary installations'
        end
      end

      def fetch_releases
        URI(RELEASES_URL).open do |io|
          JSON.parse(io.read)
        end
      rescue OpenURI::HTTPError => e
        raise InstallationError, "Failed to fetch releases: #{e.message}"
      end
    end
  end
end
