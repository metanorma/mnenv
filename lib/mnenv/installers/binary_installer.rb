# frozen_string_literal: true

require 'open-uri'
require 'json'
require 'net/http'
require 'rubygems/package'
require 'zlib'
require 'tempfile'
require_relative '../installer/base'
require_relative '../binary_repository'

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
        repo = BinaryRepository.new
        binary_version = repo.find(version)

        return if binary_version

        available = repo.all.map(&:version).first(5).join(', ')
        raise InstallationError, "Binary version #{version} not found.\n" \
                                "Available: #{available}...\n" \
                                "Or use: mnenv install #{version} --source=gemfile"
      end

      def download_binary
        url, format = binary_url_and_format
        warn "Downloading #{url}..."

        tempfile = download_to_tempfile(url)

        case format
        when 'tgz'
          extract_tgz(tempfile)
        when 'zip'
          extract_zip(tempfile)
        when 'exe'
          # Windows .exe - just copy directly
          FileUtils.cp(tempfile.path, File.join(version_dir, 'metanorma.exe'))
        else
          raise InstallationError, "Unknown binary format: #{format}"
        end
      rescue OpenURI::HTTPError => e
        raise InstallationError, "Failed to download binary: #{e.message}"
      ensure
        tempfile&.close&.unlink
      end

      def binary_url_and_format
        repo = BinaryRepository.new
        binary_version = repo.find(version)

        unless binary_version
          raise InstallationError, "Binary version #{version} not found in repository"
        end

        platform, arch, variant = detect_platform_arch_variant

        # Try to find a matching platform in the version data
        # Priority: exe for Windows, tgz for Unix, then zip as fallback
        formats = platform == 'windows' ? %w[exe zip] : %w[tgz]

        formats.each do |fmt|
          platform_data = binary_version.find_platform(
            name: platform,
            arch: arch,
            variant: variant,
            format: fmt
          )

          if platform_data && platform_data['url']
            return [platform_data['url'], fmt]
          end
        end

        # Try without variant (for non-musl systems)
        formats.each do |fmt|
          platform_data = binary_version.find_platform(
            name: platform,
            arch: arch,
            variant: nil,
            format: fmt
          )

          if platform_data && platform_data['url']
            return [platform_data['url'], fmt]
          end
        end

        # Fallback: construct URL manually (for backward compatibility)
        warn "Warning: Platform data not found in cache, constructing URL manually"
        fallback_url_and_format(platform, arch, variant)
      end

      def fallback_url_and_format(platform, arch, variant)
        tag_name = "v#{version}"

        if platform == 'windows'
          url_exe = "https://github.com/#{PACKED_MN_REPO}/releases/download/#{tag_name}/metanorma-#{platform}-#{arch}.exe"
          return [url_exe, 'exe'] if url_exists?(url_exe)

          url_zip = "https://github.com/#{PACKED_MN_REPO}/releases/download/#{tag_name}/metanorma-#{platform}-#{arch}.zip"
          return [url_zip, 'zip'] if url_exists?(url_zip)

          raise InstallationError, "No Windows binary found for version #{version}"
        else
          # Try with variant (e.g., musl)
          if variant
            url_variant = "https://github.com/#{PACKED_MN_REPO}/releases/download/#{tag_name}/metanorma-#{platform}-#{variant}-#{arch}.tgz"
            return [url_variant, 'tgz'] if url_exists?(url_variant)
          end

          url_with_arch = "https://github.com/#{PACKED_MN_REPO}/releases/download/#{tag_name}/metanorma-#{platform}-#{arch}.tgz"
          return [url_with_arch, 'tgz'] if url_exists?(url_with_arch)

          raise InstallationError, "No binary found for #{platform}/#{arch} version #{version}"
        end
      end

      def download_to_tempfile(url)
        tempfile = Tempfile.new(['mnenv-binary', '.tmp'])
        URI.open(url, 'rb') do |io|
          IO.copy_stream(io, tempfile)
        end
        tempfile.rewind
        tempfile
      end

      def extract_tgz(tempfile)
        found = false
        Gem::Package::TarReader.new(Zlib::GzipReader.open(tempfile.path)) do |tar|
          tar.each do |entry|
            next unless entry.file?

            # Look for the metanorma binary
            # The archive may contain:
            # - metanorma (expected)
            # - metanorma-linux-x86_64 (actual packed-mn naming)
            # - metanorma-darwin-arm64
            # etc.
            filename = File.basename(entry.full_name)
            next unless filename.start_with?('metanorma') && !filename.include?('.')

            target_name = if filename == 'metanorma'
                            'metanorma'
                          else
                            # Rename metanorma-linux-x86_64 to just metanorma
                            'metanorma'
                          end

            File.open(File.join(version_dir, target_name), 'wb') do |f|
              f.write(entry.read)
            end
            found = true
            break
          end
        end

        raise InstallationError, 'Could not find metanorma binary in archive' unless found
      end

      def extract_zip(tempfile)
        require 'zip'

        Zip::File.open(tempfile.path) do |zip_file|
          entry = zip_file.find { |e| File.basename(e.name) == 'metanorma.exe' }
          raise InstallationError, 'Could not find metanorma.exe in zip archive' unless entry

          File.open(File.join(version_dir, 'metanorma.exe'), 'wb') do |f|
            f.write(entry.get_input_stream.read)
          end
        end
      end

      def url_exists?(url)
        uri = URI(url)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
          response = http.head(uri.path)
          response.is_a?(Net::HTTPSuccess)
        end
      rescue StandardError
        false
      end

      def detect_platform_arch_variant
        platform = case RbConfig::CONFIG['host_os']
                   when /linux/   then 'linux'
                   when /darwin/  then 'darwin'
                   when /mswin|mingw|cygwin/ then 'windows'
                   else raise InstallationError, 'Unsupported platform for binary installations'
                   end

        # Detect architecture
        arch = case RbConfig::CONFIG['host_cpu']
               when /arm64|aarch64/ then 'arm64'
               when /x86_64|x64/ then 'x86_64'
               else 'x86_64' # Default to x86_64
               end

        # Detect variant (e.g., musl for Alpine Linux)
        variant = detect_variant if platform == 'linux'

        [platform, arch, variant]
      end

      def detect_variant
        # Check for musl libc (Alpine Linux)
        if File.exist?('/etc/alpine-release')
          'musl'
        elsif File.symlink?('/lib/libc.musl-x86_64.so.1')
          'musl'
        else
          nil
        end
      rescue StandardError
        nil
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
