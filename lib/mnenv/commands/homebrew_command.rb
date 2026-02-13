# frozen_string_literal: true

require 'thor'
require 'json'

module Mnenv
  autoload :HomebrewRepository, 'mnenv/homebrew_repository'
  autoload :JsonFormatter, 'mnenv/json_formatter'
  autoload :Homebrew, 'mnenv/homebrew'

  class HomebrewCommand < Thor
    desc 'list', 'List all Homebrew versions'
    method_option :format, type: :string, aliases: '-f', default: 'text'
    def list
      repo = HomebrewRepository.new
      versions = repo.all

      case options[:format]
      when 'json'
        output = JsonFormatter.format_versions(versions)
        output['platform'] = 'homebrew'
        puts JSON.pretty_generate(output)
      else
        list_versions_text(versions, 'Homebrew')
      end
    end

    desc 'refresh', 'Fetch and add new Homebrew versions'
    def refresh
      fetcher = Homebrew::Fetcher.new
      existing = fetcher.repository.all.map(&:version)
      remote_versions = fetcher.fetch_all
      new_versions = remote_versions.reject { |v| existing.include?(v.version) }

      if new_versions.empty?
        puts 'No new Homebrew versions found'
      else
        fetcher.repository.save_all(new_versions)
        puts "Added #{new_versions.size} new Homebrew versions"
      end
    end

    desc 'revamp', 'Re-fetch all Homebrew versions'
    def revamp
      fetcher = Homebrew::Fetcher.new
      versions = fetcher.fetch_and_save
      puts "Revamped #{versions.size} Homebrew versions"
    end

    desc 'update VERSION', 'Update a specific Homebrew version'
    def update(version)
      fetcher = Homebrew::Fetcher.new
      versions = fetcher.fetch_all
      target = versions.find { |v| v.version == version }

      if target
        fetcher.repository.save(target)
        puts "Updated Homebrew version #{version}"
      else
        puts "Homebrew version #{version} not found"
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
