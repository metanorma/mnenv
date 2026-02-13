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

      File.write(Paths::VERSION_FILE, version)
      File.write(Paths::SOURCE_FILE, source) if source
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
      installed = list_installed_versions

      if installed.empty?
        puts 'No versions installed.'
        puts "\nRun: mnenv install --list"
        return
      end

      current_version, current_source = resolve_current

      case options[:format]
      when 'json'
        output = {
          'current_version' => current_version,
          'current_source' => current_source,
          'installed' => installed.map do |version, sources|
            sources.map do |source|
              {
                'version' => version,
                'source' => source,
                'current' => version == current_version && source == current_source
              }
            end
          end.flatten
        }
        puts JSON.pretty_generate(output)
      else
        puts 'Installed Metanorma versions:'

        installed.sort.reverse.each do |version, sources|
          sources.sort.each do |source|
            is_current = version == current_version && source == current_source
            marker = is_current ? '* ' : '  '
            puts "  #{marker}#{version} (source: #{source})"
          end
        end

        puts "\nCurrent version: #{current_version || 'none'}"
        puts "Current source: #{current_source || 'none'}"
        puts "\nTo see available versions, run: mnenv install --list"
      end
    end

    private

    # List installed versions with their sources
    # Uses Paths::INSTALLED_DIR (not the versions data directory)
    def list_installed_versions
      return {} unless Dir.exist?(Paths::INSTALLED_DIR)

      versions = Hash.new { |h, k| h[k] = [] }

      Dir.glob("#{Paths::INSTALLED_DIR}/*/").sort.each do |dir|
        version = File.basename(dir)
        source_file = File.join(dir, 'source')

        # Only include directories that have a valid source file
        next unless File.exist?(source_file)

        source = File.read(source_file).strip
        next if source.empty?

        versions[version] << source
      end

      versions
    end

    def resolve_version_and_source(version, source, interactive)
      version, source = select_version_interactive if interactive || version.nil?
      source ||= default_source
      [version, source]
    end

    def select_version_interactive
      prompt = TTY::Prompt.new
      choices = installed_versions.map do |v|
        source_file = File.join(Paths.version_install_dir(v), 'source')
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
      version_dir = Paths.version_install_dir(version)
      unless Dir.exist?(version_dir)
        raise "Version #{version} is not installed. Run: mnenv install #{version}#{" --source #{source}" if source}"
      end

      return unless source

      source_file = File.join(version_dir, 'source')
      return unless File.exist?(source_file) && File.read(source_file).strip != source

      raise "Version #{version} is installed with source #{File.read(source_file).strip}, not #{source}"
    end

    def installed_versions
      return [] unless Dir.exist?(Paths::INSTALLED_DIR)

      Dir.glob("#{Paths::INSTALLED_DIR}/*/").filter_map do |dir|
        version = File.basename(dir)
        source_file = File.join(dir, 'source')
        # Only include directories that have a valid source file
        version if File.exist?(source_file)
      end.sort
    end

    def default_source
      if File.exist?(Paths::SOURCE_FILE)
        File.read(Paths::SOURCE_FILE).strip
      else
        'gemfile'
      end
    end

    def resolve_version
      return ENV['MNENV_VERSION'] if ENV['MNENV_VERSION']

      dir = Dir.pwd
      loop do
        return File.read(File.join(dir, '.metanorma-version')).strip if File.exist?(File.join(dir,
                                                                                              '.metanorma-version'))

        parent = File.dirname(dir)
        break if parent == dir # Reached root

        dir = parent
      end

      return File.read(Paths::VERSION_FILE).strip if File.exist?(Paths::VERSION_FILE)

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

      return File.read(Paths::SOURCE_FILE).strip if File.exist?(Paths::SOURCE_FILE)

      'gemfile'
    end

    def resolve_current
      [resolve_version, resolve_source]
    end
  end
end
