# frozen_string_literal: true

require 'open-uri'
require 'json'
require 'net/http'
require 'rubygems/package'
require 'zlib'
require 'tempfile'
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
        url, extension = binary_url_with_extension
        warn "Downloading #{url}..."

        tempfile = download_to_tempfile(url)

        if extension == '.tgz'
          extract_tgz(tempfile)
        elsif extension == '.zip'
          extract_zip(tempfile)
        else
          # Windows .exe - just copy directly
          FileUtils.cp(tempfile.path, File.join(version_dir, 'metanorma.exe'))
        end
      rescue OpenURI::HTTPError => e
        raise InstallationError, "Failed to download binary: #{e.message}"
      ensure
        tempfile&.close&.unlink
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

            # Look for the metanorma binary (could be at root or in a subdirectory)
            filename = File.basename(entry.full_name)
            next unless filename == 'metanorma'

            File.open(File.join(version_dir, 'metanorma'), 'wb') do |f|
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

      def binary_url_with_extension
        platform, arch = detect_platform_and_arch
        tag_name = "v#{version}"

        if platform == 'windows'
          # Windows: try .exe first, then .zip
          url_exe = "https://github.com/#{PACKED_MN_REPO}/releases/download/#{tag_name}/metanorma-#{platform}-#{arch}.exe"
          return [url_exe, '.exe'] if url_exists?(url_exe)

          url_zip = "https://github.com/#{PACKED_MN_REPO}/releases/download/#{tag_name}/metanorma-#{platform}-#{arch}.zip"
          return [url_zip, '.zip'] if url_exists?(url_zip)

          # Try without arch (assumed x86_64)
          url_exe_no_arch = "https://github.com/#{PACKED_MN_REPO}/releases/download/#{tag_name}/metanorma-#{platform}.exe"
          return [url_exe_no_arch, '.exe'] if url_exists?(url_exe_no_arch)

          raise InstallationError, "No Windows binary found for version #{version}"
        else
          # Linux/macOS: try .tgz with arch, then without arch (assumed x86_64)
          url_with_arch = "https://github.com/#{PACKED_MN_REPO}/releases/download/#{tag_name}/metanorma-#{platform}-#{arch}.tgz"
          return [url_with_arch, '.tgz'] if url_exists?(url_with_arch)

          # Try without arch (assumed x86_64/x64)
          url_no_arch = "https://github.com/#{PACKED_MN_REPO}/releases/download/#{tag_name}/metanorma-#{platform}.tgz"
          return [url_no_arch, '.tgz'] if url_exists?(url_no_arch)

          raise InstallationError, "No binary found for #{platform}/#{arch} version #{version}"
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

      def detect_platform_and_arch
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

        [platform, arch]
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
