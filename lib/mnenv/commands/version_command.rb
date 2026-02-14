# frozen_string_literal: true

require 'tty/prompt'
require 'json'
require_relative '../installer'
require_relative '../version_resolver'

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

      puts "export METANORMA_VERSION=#{version}"
      puts "export METANORMA_SOURCE=#{source}" if source
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

      current_version, current_source = resolver.resolve

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

    # Get the shared resolver instance
    def resolver
      @resolver ||= VersionResolver.new
    end

    # List installed versions with their sources
    # Uses Paths::INSTALLED_DIR with new naming convention: <version>-<source>
    def list_installed_versions
      return {} unless Dir.exist?(Paths::INSTALLED_DIR)

      versions = Hash.new { |h, k| h[k] = [] }

      Dir.glob(File.join(Paths::INSTALLED_DIR, '*')).each do |dir|
        next unless File.directory?(dir)

        dir_name = File.basename(dir)
        version, source = Paths.parse_version_dir(dir_name)

        # Only include valid version-source directories
        next unless version && source

        versions[version] << source
      end

      versions
    end

    def resolve_version_and_source(version, source, interactive)
      version, source = select_version_interactive if interactive || version.nil?
      source ||= resolver.resolve_source
      [version, source]
    end

    def select_version_interactive
      prompt = TTY::Prompt.new
      installed = list_installed_versions

      raise 'No versions installed. Run: mnenv install --list' if installed.empty?

      choices = installed.flat_map do |version, sources|
        sources.map do |src|
          { name: "#{version} (#{src})", value: [version, src] }
        end
      end

      prompt.select('Select a version:', choices)
    end

    def verify_installed!(version, source)
      version_dir = Paths.version_install_dir(version, source)
      return if Dir.exist?(version_dir)

      raise "Version #{version} (source: #{source}) is not installed. Run: mnenv install #{version} --source #{source}"
    end

    def installed_versions
      list_installed_versions.keys.sort
    end
  end
end
