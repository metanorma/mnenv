# frozen_string_literal: true

require 'thor'
require 'json'

module Mnenv
  autoload :ChocolateyRepository, 'mnenv/chocolatey_repository'
  autoload :JsonFormatter, 'mnenv/json_formatter'
  autoload :Chocolatey, 'mnenv/chocolatey'

  class ChocolateyCommand < Thor
    desc 'list', 'List all Chocolatey versions'
    method_option :format, type: :string, aliases: '-f', default: 'text'
    def list
      repo = ChocolateyRepository.new
      versions = repo.all

      case options[:format]
      when 'json'
        output = JsonFormatter.format_versions(versions)
        output['platform'] = 'chocolatey'
        puts JSON.pretty_generate(output)
      else
        list_versions_text(versions, 'Chocolatey')
      end
    end

    desc 'refresh', 'Fetch and add new Chocolatey versions'
    def refresh
      fetcher = Chocolatey::Fetcher.new
      existing = fetcher.repository.all.map(&:version)
      remote_versions = fetcher.fetch_all
      new_versions = remote_versions.reject { |v| existing.include?(v.version) }

      if new_versions.empty?
        puts 'No new Chocolatey versions found'
      else
        fetcher.repository.save_all(new_versions)
        puts "Added #{new_versions.size} new Chocolatey versions"
      end
    end

    desc 'revamp', 'Re-fetch all Chocolatey versions'
    def revamp
      fetcher = Chocolatey::Fetcher.new
      versions = fetcher.fetch_and_save
      puts "Revamped #{versions.size} Chocolatey versions"
    end

    desc 'update VERSION', 'Update a specific Chocolatey version'
    def update(version)
      fetcher = Chocolatey::Fetcher.new
      versions = fetcher.fetch_all
      target = versions.find { |v| v.version == version }

      if target
        fetcher.repository.save(target)
        puts "Updated Chocolatey version #{version}"
      else
        puts "Chocolatey version #{version} not found"
        exit 1
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
