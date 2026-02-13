# frozen_string_literal: true

require 'json'
require_relative '../version'
require_relative '../binary_repository'

module Mnenv
  class AvailableCommand < Thor
    namespace :available

    class_option :source, type: :string, enum: %w[gemfile binary all], default: 'all',
                          desc: 'Source type to show (gemfile, binary, or all)'
    class_option :format, type: :string, aliases: '-f', default: 'text',
                          desc: 'Output format (text or json)'

    desc 'gemfile', 'List available Metanorma versions from RubyGems (gemfile method)'
    method_option :format, type: :string, aliases: '-f', default: 'text'
    def gemfile
      repo = GemfileRepository.new
      versions = repo.all.sort.reverse

      show_available_versions('gemfile', versions)
    end

    desc 'binary', 'List available Metanorma versions from GitHub releases (binary method)'
    method_option :format, type: :string, aliases: '-f', default: 'text'
    def binary
      repo = BinaryRepository.new
      versions = repo.all

      show_available_versions('binary', versions)
    end

    desc 'all', 'List all available Metanorma versions from all sources'
    method_option :format, type: :string, aliases: '-f', default: 'text'
    def all
      case options[:format]
      when 'json'
        output = {}
        output['gemfile'] = format_versions_json(GemfileRepository.new.all.sort.reverse)
        output['binary'] = format_versions_json(BinaryRepository.new.all)
        puts JSON.pretty_generate(output)
      else
        puts "\n=== Gemfile (RubyGems) ==="
        gemfile

        puts "\n=== Binary (packed-mn releases) ==="
        binary
      end
    end

    default_task :all

    private

    def show_available_versions(source, versions)
      current_version, current_source = resolve_current

      case options[:format]
      when 'json'
        output = {
          'source' => source,
          'versions' => format_versions_json(versions)
        }
        puts JSON.pretty_generate(output)
      else
        puts "Available Metanorma versions (source: #{source}):"

        versions.each do |v|
          # Check if installed
          version_dir = File.expand_path("~/.mnenv/versions/#{v.version}")
          installed = Dir.exist?(version_dir)

          # Check installed source
          installed_source = if installed
                               source_file = File.join(version_dir, 'source')
                               File.exist?(source_file) ? File.read(source_file).strip : 'unknown'
                             end

          # Check if currently active
          is_current = installed && v.version == current_version && installed_source == current_source

          # Build status indicator
          status_parts = []
          status_parts << 'current' if is_current
          status_parts << 'installed' if installed && !is_current
          status = status_parts.empty? ? '' : " [#{status_parts.join(', ')}]"

          # Show installed source if different
          source_info = if installed && installed_source && installed_source != source
                          " (as #{installed_source})"
                        elsif installed && installed_source == source
                          ''
                        end

          # Version display with padding
          version_display = v.display_name
          marker = is_current ? '*' : ' '
          padding = ' ' * (15 - version_display.length - status.length)

          puts "  #{marker} #{version_display}#{padding}#{status}#{source_info}"
        end
      end
    end

    def format_versions_json(versions)
      versions.map do |v|
        version_dir = File.expand_path("~/.mnenv/versions/#{v.version}")
        installed = Dir.exist?(version_dir)
        installed_source = if installed
                             source_file = File.join(version_dir, 'source')
                             File.exist?(source_file) ? File.read(source_file).strip : nil
                           end

        {
          'version' => v.version,
          'display_name' => v.display_name,
          'published_at' => v.published_at&.iso8601,
          'installed' => installed,
          'installed_source' => installed_source
        }
      end
    end

    def resolve_current
      # Get current version
      version = ENV['MNENV_VERSION']
      unless version
        # Check .metanorma-version file
        dir = Dir.pwd
        while dir && dir != '/'
          if File.exist?(File.join(dir, '.metanorma-version'))
            version = File.read(File.join(dir, '.metanorma-version')).strip
            break
          end
          dir = File.dirname(dir)
        end

        # Check global version
        version ||= begin
          global_version_file = File.expand_path('~/.mnenv/version')
          File.read(global_version_file).strip if File.exist?(global_version_file)
        end
      end

      # Get current source
      source = ENV['MNENV_SOURCE']
      unless source
        # Check .metanorma-source file
        dir = Dir.pwd
        while dir && dir != '/'
          if File.exist?(File.join(dir, '.metanorma-source'))
            source = File.read(File.join(dir, '.metanorma-source')).strip
            break
          end
          dir = File.dirname(dir)
        end

        # Check global source
        source ||= begin
          global_source_file = File.expand_path('~/.mnenv/source')
          File.read(global_source_file).strip if File.exist?(global_source_file)
        end
      end

      [version, source]
    end
  end
end
