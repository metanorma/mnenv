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
      existing = fetcher.repository.all.map(&:version)
      remote_versions = fetcher.fetch_all
      new_versions = remote_versions.reject { |v| existing.include?(v.version) }

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

    desc 'update VERSION', 'Update a specific Snap version'
    def update(version)
      fetcher = Snap::Fetcher.new
      versions = fetcher.fetch_all
      target = versions.find { |v| v.version == version }

      if target.nil?
        puts "Snap version #{version} not found"
        exit 1
      end

      fetcher.repository.save_all([target])
      puts "Updated 1 Snap entry for version #{version}:"
      target.channels.each do |v|
        puts "  - channel: #{v.name} arch: #{v.arch} revision: #{v.revision}"
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
