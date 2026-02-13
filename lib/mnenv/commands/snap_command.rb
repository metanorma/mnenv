# frozen_string_literal: true

require 'thor'
require 'json'

module Mnenv
  autoload :SnapRepository, 'mnenv/snap_repository'
  autoload :JsonFormatter, 'mnenv/json_formatter'
  autoload :Snap, 'mnenv/snap'

  class SnapCommand < Thor
    desc 'list', 'List all Snap versions'
    method_option :format, type: :string, aliases: '-f', default: 'text'
    def list
      repo = SnapRepository.new
      versions = repo.all

      case options[:format]
      when 'json'
        output = JsonFormatter.format_versions(versions)
        output['platform'] = 'snap'
        puts JSON.pretty_generate(output)
      else
        list_versions_text(versions, 'Snap')
      end
    end

    desc 'refresh', 'Fetch and add new Snap versions (incremental)'
    def refresh
      fetcher = Snap::Fetcher.new
      repo = fetcher.repository

      # Build map of existing composite keys
      existing_keys = repo.all.map { |v| "#{v.version}-#{v.revision}-#{v.arch}-#{v.channel}" }
      remote_versions = fetcher.fetch_all

      # Find truly new versions (composite key doesn't exist)
      new_versions = remote_versions.reject do |v|
        key = "#{v.version}-#{v.revision}-#{v.arch}-#{v.channel}"
        existing_keys.include?(key)
      end

      if new_versions.empty?
        puts 'No new Snap versions found'
      else
        repo.save_all(new_versions)
        puts "Added #{new_versions.size} new Snap versions"
      end
    end

    desc 'revamp', 'Re-fetch all Snap versions'
    def revamp
      fetcher = Snap::Fetcher.new
      versions = fetcher.fetch_and_save
      puts "Revamped #{versions.size} Snap versions"
    end

    desc 'update VERSION', 'Update a specific Snap version (all arch/channel combinations)'
    def update(version)
      fetcher = Snap::Fetcher.new
      versions = fetcher.fetch_all
      targets = versions.select { |v| v.version == version }

      if targets.empty?
        puts "Snap version #{version} not found in current channel-map"
        puts 'Note: Historical versions no longer in Snap API cannot be updated'
        exit 1
      end

      fetcher.repository.save_all(targets)
      puts "Updated #{targets.size} Snap entries for version #{version}:"
      targets.each do |v|
        puts "  - #{v.arch}/#{v.channel}: revision #{v.revision}"
      end
    end

    private

    def list_versions_text(versions, name)
      puts "#{name} versions (#{versions.size}):"
      versions.each do |v|
        published = v.published_at ? " (#{v.published_at.strftime('%Y-%m-%d')})" : ''
        puts "  #{v.display_name}#{published}"
      end
    end
  end
end
