# frozen_string_literal: true

require_relative 'repository'
require_relative 'models/snap_version'

module Mnenv
  class SnapRepository < Repository
    def version_class = SnapVersion
    def source_name = :snap

    # Override cache_version to use composite key for Snap
    # Since same version can have multiple revisions/arch/channels
    def cache_version(version)
      @versions_cache[snap_key(version)] = version
    end

    # Override find to work with composite keys
    def find(version_number)
      @versions_cache.values.find { |v| v.version == version_number }
    end

    # Find by specific version, revision, arch, channel
    def find_exact(version_number, revision, arch, channel)
      @versions_cache[snap_key(version_number, revision, arch, channel)]
    end

    # Get all entries for a specific version
    def find_all_by_version(version_number)
      @versions_cache.values.select { |v| v.version == version_number }.sort
    end

    def exists?(version_number)
      @versions_cache.values.any? { |v| v.version == version_number }
    end

    private

    def snap_key(*args)
      case args.size
      when 1
        # Single SnapVersion object
        v = args.first
        "#{v.version}-#{v.revision}-#{v.arch}-#{v.channel}"
      when 4
        # version, revision, arch, channel
        version_number, revision, arch, channel = args
        "#{version_number}-#{revision}-#{arch}-#{channel}"
      else
        raise ArgumentError, 'snap_key requires 1 or 4 arguments'
      end
    end
  end
end
