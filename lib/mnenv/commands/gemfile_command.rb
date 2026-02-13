# frozen_string_literal: true

require 'thor'
require 'json'

module Mnenv
  autoload :GemfileRepository, 'mnenv/gemfile_repository'
  autoload :JsonFormatter, 'mnenv/json_formatter'
  autoload :Gemfile, 'mnenv/gemfile'

  class GemfileCommand < Thor
    desc 'list', 'List all Gemfile (Ruby) versions'
    method_option :format, type: :string, aliases: '-f', default: 'text'
    def list
      repo = GemfileRepository.new
      versions = repo.all

      case options[:format]
      when 'json'
        output = JsonFormatter.format_versions(versions)
        output['platform'] = 'ruby'
        puts JSON.pretty_generate(output)
      else
        list_versions_text(versions, 'Ruby (Gemfile)')
      end
    end

    desc 'refresh', 'Extract new Gemfiles (incremental mode)'
    def refresh
      extractor = Gemfile::Extractor.new(mode: :incremental)
      extractor.run
    end

    desc 'revamp', 'Re-extract all Gemfiles'
    def revamp
      extractor = Gemfile::Extractor.new(mode: :revamp)
      extractor.run
    end

    desc 'update VERSION', 'Re-extract specific version'
    def update(version)
      extractor = Gemfile::Extractor.new(mode: :replace, target_version: version)
      extractor.run
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
