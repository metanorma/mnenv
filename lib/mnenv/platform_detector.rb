# frozen_string_literal: true

module Mnenv
  # Centralized platform detection for consistent OS/architecture/variant detection
  # across the codebase. Used by binary installer, repository, and CLI.
  class PlatformDetector
    class UnsupportedPlatform < StandardError; end

    class << self
      # Detect the current operating system
      # @return [String] 'linux', 'darwin', or 'windows'
      # @raise [UnsupportedPlatform] if platform is not supported
      def os
        case RbConfig::CONFIG['host_os']
        when /linux/
          'linux'
        when /darwin/
          'darwin'
        when /mswin|mingw|cygwin/
          'windows'
        else
          raise UnsupportedPlatform, "Unsupported platform: #{RbConfig::CONFIG['host_os']}"
        end
      end

      # Detect the current CPU architecture
      # @return [String] 'arm64' or 'x86_64'
      def arch
        case RbConfig::CONFIG['host_cpu']
        when /arm64|aarch64/
          'arm64'
        when /x86_64|x64/
          'x86_64'
        else
          'x86_64' # Default fallback
        end
      end

      # Detect libc variant (for Linux)
      # @return [String, nil] 'musl' for Alpine/musl systems, nil for glibc
      def variant
        return nil unless os == 'linux'

        'musl' if musl?
      end

      # Check if running on a musl-based system (Alpine Linux)
      # @return [Boolean]
      def musl?
        File.exist?('/etc/alpine-release') ||
          File.symlink?('/lib/libc.musl-x86_64.so.1')
      rescue StandardError
        false
      end

      # Check if running on Windows
      # @return [Boolean]
      def windows?
        os == 'windows'
      end

      # Check if running on macOS
      # @return [Boolean]
      def macos?
        os == 'darwin'
      end

      # Check if running on Linux
      # @return [Boolean]
      def linux?
        os == 'linux'
      end

      # Get platform info as a hash
      # @return [Hash] With keys :os, :arch, :variant
      def to_h
        {
          os: os,
          arch: arch,
          variant: variant
        }
      end

      # Get a human-readable platform string
      # @return [String] e.g., "linux-x86_64", "darwin-arm64", "linux-musl-x86_64"
      def platform_string
        parts = [os]
        parts << variant if variant
        parts << arch
        parts.join('-')
      end

      # Get all possible platform strings for binary matching
      # (includes variant-specific and generic versions)
      # @return [Array<String>] List of platform strings in order of preference
      def platform_candidates
        candidates = []

        # With variant (if applicable)
        candidates << "#{os}-#{variant}-#{arch}" if variant

        # Without variant
        candidates << "#{os}-#{arch}"

        candidates
      end
    end
  end
end
