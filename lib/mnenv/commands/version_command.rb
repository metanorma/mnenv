# frozen_string_literal: true

require 'tty/prompt'
require 'json'
require_relative '../installer'
require_relative '../binary_repository'

module Mnenv
  class VersionCommand < Thor
    namespace :version

    class_option :source, type: :string, enum: %w[gemfile binary],
                          desc: 'Source type (gemfile or binary)'
    class_option :interactive, type: :boolean, aliases: '-i', default: false,
                               desc: 'Interactive mode for version selection'

    desc 'use VERSION', 'Set Metanorma version for current shell session'
    method_option :source, type: :string, enum: %w[gemfile binary]
    method_option :interactive, type: :boolean, aliases: '-i', default: false
    def use(version = nil)
      version, source = resolve_version_and_source(version, options[:source], options[:interactive])

      puts "export MNENV_VERSION=#{version}"
      puts "export MNENV_SOURCE=#{source}" if source
      puts "# Run this in your shell, or use: eval \"$(mnenv use #{version}#{" --source #{source}" if source})\""
    end

    desc 'global VERSION', 'Set default Metanorma version globally'
    method_option :source, type: :string, enum: %w[gemfile binary]
    method_option :interactive, type: :boolean, aliases: '-i', default: false
    def global(version = nil)
      version, source = resolve_version_and_source(version, options[:source], options[:interactive])
      verify_installed!(version, source)

      File.write(File.expand_path('~/.mnenv/version'), version)
      File.write(File.expand_path('~/.mnenv/source'), source) if source
      puts "Global Metanorma version set to #{version}#{source ? " (source: #{source})" : ''}"
    rescue StandardError => e
      warn "Error: #{e.message}"
      exit 1
    end

    desc 'local VERSION', 'Set Metanorma version for current directory'
    method_option :source, type: :string, enum: %w[gemfile binary]
    method_option :interactive, type: :boolean, aliases: '-i', default: false
    def local(version = nil)
      version, source = resolve_version_and_source(version, options[:source], options[:interactive])
      verify_installed!(version, source)

      File.write('.metanorma-version', version)
      File.write('.metanorma-source', source) if source
      puts "Local Metanorma version set to #{version}#{source ? " (source: #{source})" : ''}"
      puts "Created .metanorma-version#{source ? ' and .metanorma-source' : ''}"
    rescue StandardError => e
      warn "Error: #{e.message}"
      exit 1
    end

    desc 'versions', 'List all installed Metanorma versions'
    method_option :format, type: :string, aliases: '-f', default: 'text',
                           desc: 'Output format (text or json)'
    def versions
      versions_dir = File.expand_path('~/.mnenv/versions')

      unless Dir.exist?(versions_dir)
        puts 'No versions installed.'
        puts "\nRun: mnenv available"
        return
      end

      current_version, current_source = resolve_current

      case options[:format]
      when 'json'
        installed = []
        Dir.glob("#{versions_dir}/*/").sort.each do |dir|
          version = File.basename(dir)
          source_file = File.join(dir, 'source')
          source = File.exist?(source_file) ? File.read(source_file).strip : 'unknown'
          is_current = version == current_version && source == current_source
          installed << {
            'version' => version,
            'source' => source,
            'current' => is_current
          }
        end

        output = {
          'current_version' => current_version,
          'current_source' => current_source,
          'installed' => installed
        }
        puts JSON.pretty_generate(output)
      else
        puts 'Installed Metanorma versions:'

        versions_by_name = Hash.new { |h, k| h[k] = [] }
        Dir.glob("#{versions_dir}/*/").sort.each do |dir|
          version = File.basename(dir)
          source_file = File.join(dir, 'source')
          source = File.exist?(source_file) ? File.read(source_file).strip : 'unknown'
          versions_by_name[version] << source
        end

        versions_by_name.sort.reverse.each do |version, sources|
          sources.sort.each do |source|
            is_current = version == current_version && source == current_source
            marker = is_current ? '* ' : '  '
            puts "  #{marker}#{version} (source: #{source})"
          end
        end

        puts "\nCurrent version: #{current_version || 'none'}"
        puts "Current source: #{current_source || 'none'}"
        puts "\nTo see available versions, run: mnenv available"
      end
    end

    private

    def resolve_version_and_source(version, source, interactive)
      version, source = select_version_interactive if interactive || version.nil?
      source ||= default_source
      [version, source]
    end

    def select_version_interactive
      prompt = TTY::Prompt.new
      choices = installed_versions.map do |v|
        source_file = File.expand_path("~/.mnenv/versions/#{v}/source")
        src = File.exist?(source_file) ? File.read(source_file).strip : 'unknown'
        { name: "#{v} (#{src})", value: v }
      end

      raise 'No versions installed. Run: mnenv install --list' if choices.empty?

      version = prompt.select('Select a version:', choices)

      source = prompt.select('Select source:', [
                               { name: 'gemfile', value: 'gemfile' },
                               { name: 'binary', value: 'binary' }
                             ])

      [version, source]
    end

    def verify_installed!(version, source)
      version_dir = File.expand_path("~/.mnenv/versions/#{version}")
      unless Dir.exist?(version_dir)
        raise "Version #{version} is not installed. Run: mnenv install #{version}#{" --source #{source}" if source}"
      end

      return unless source

      source_file = File.join(version_dir, 'source')
      return unless File.exist?(source_file) && File.read(source_file).strip != source

      raise "Version #{version} is installed with source #{File.read(source_file).strip}, not #{source}"
    end

    def installed_versions
      Dir.glob(File.expand_path('~/.mnenv/versions/*/')).map { |d| File.basename(d) }.sort
    end

    def default_source
      global_source_file = File.expand_path('~/.mnenv/source')
      if File.exist?(global_source_file)
        File.read(global_source_file).strip
      else
        'gemfile'
      end
    end

    def resolve_version
      return ENV['MNENV_VERSION'] if ENV['MNENV_VERSION']

      dir = Dir.pwd
      loop do
        return File.read(File.join(dir, '.metanorma-version')).strip if File.exist?(File.join(dir, '.metanorma-version'))

        parent = File.dirname(dir)
        break if parent == dir # Reached root

        dir = parent
      end

      global_version_file = File.expand_path('~/.mnenv/version')
      return File.read(global_version_file).strip if File.exist?(global_version_file)

      nil
    end

    def resolve_source
      return ENV['MNENV_SOURCE'] if ENV['MNENV_SOURCE']

      dir = Dir.pwd
      loop do
        return File.read(File.join(dir, '.metanorma-source')).strip if File.exist?(File.join(dir, '.metanorma-source'))

        parent = File.dirname(dir)
        break if parent == dir # Reached root

        dir = parent
      end

      global_source_file = File.expand_path('~/.mnenv/source')
      return File.read(global_source_file).strip if File.exist?(global_source_file)

      'gemfile'
    end

    def resolve_current
      [resolve_version, resolve_source]
    end
  end
end
