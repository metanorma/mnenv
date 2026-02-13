# frozen_string_literal: true

require 'thor'
require 'json'

module Mnenv
  # Autoload constants for lazy loading
  autoload :VERSION, 'mnenv/version'
  autoload :GemfileRepository, 'mnenv/gemfile_repository'
  autoload :SnapRepository, 'mnenv/snap_repository'
  autoload :HomebrewRepository, 'mnenv/homebrew_repository'
  autoload :ChocolateyRepository, 'mnenv/chocolatey_repository'
  autoload :GemfileCommand, 'mnenv/commands/gemfile_command'
  autoload :SnapCommand, 'mnenv/commands/snap_command'
  autoload :HomebrewCommand, 'mnenv/commands/homebrew_command'
  autoload :ChocolateyCommand, 'mnenv/commands/chocolatey_command'
  autoload :InstallCommand, 'mnenv/commands/install_command'
  autoload :VersionCommand, 'mnenv/commands/version_command'
  autoload :AvailableCommand, 'mnenv/commands/available_command'
  autoload :UninstallCommand, 'mnenv/commands/uninstall_command'
  autoload :JsonFormatter, 'mnenv/json_formatter'
  autoload :ShimManager, 'mnenv/shim_manager'
  autoload :BinaryRepository, 'mnenv/binary_repository'

  class Cli < Thor
    package_name 'mnenv'

    # Global options
    class_option :verbose, type: :boolean, default: false, desc: 'Enable verbose output'

    # Track verbose mode for use in other classes
    class << self
      def verbose?
        @verbose ||= false
      end

      attr_writer :verbose
    end

    def initialize(*args)
      super
      self.class.verbose = options[:verbose]
    end

    # Platform subcommands
    desc 'gemfile SUBCOMMAND', 'Manage Ruby (Gemfile) versions'
    subcommand 'gemfile', GemfileCommand

    desc 'snap SUBCOMMAND', 'Manage Snap versions'
    subcommand 'snap', SnapCommand

    desc 'homebrew SUBCOMMAND', 'Manage Homebrew versions'
    subcommand 'homebrew', HomebrewCommand

    desc 'chocolatey SUBCOMMAND', 'Manage Chocolatey versions'
    subcommand 'chocolatey', ChocolateyCommand

    # Interactive installation commands
    desc 'install [VERSION]', 'Install a Metanorma version'
    method_option :source, type: :string, enum: %w[gemfile binary], default: 'gemfile',
                           desc: 'Installation source (gemfile or binary)'
    method_option :interactive, type: :boolean, aliases: '-i', default: false,
                                desc: 'Interactive mode for version selection'
    def install(version = nil)
      cmd = InstallCommand.new
      cmd.options = Thor::CoreExt::HashWithIndifferentAccess.new(options.merge(version: version))
      if version.nil? && options[:interactive]
        cmd.install(nil, options)
      elsif version == '--list'
        cmd.list
      else
        cmd.install(version, options)
      end
    rescue Thor::UndefinedCommandError
      # Handle --list flag
      cmd = InstallCommand.new
      cmd.list
    end

    desc 'use [VERSION]', 'Set Metanorma version for current shell session'
    method_option :source, type: :string, enum: %w[gemfile binary],
                           desc: 'Source type (gemfile or binary)'
    method_option :interactive, type: :boolean, aliases: '-i', default: false,
                                desc: 'Interactive mode for version selection'
    def use(version = nil)
      cmd = VersionCommand.new
      cmd.options = options
      cmd.use(version)
    end

    desc 'global [VERSION]', 'Set default Metanorma version globally'
    method_option :source, type: :string, enum: %w[gemfile binary],
                           desc: 'Source type (gemfile or binary)'
    method_option :interactive, type: :boolean, aliases: '-i', default: false,
                                desc: 'Interactive mode for version selection'
    def global(version = nil)
      cmd = VersionCommand.new
      cmd.options = options
      cmd.global(version)
    end

    desc 'local [VERSION]', 'Set Metanorma version for current directory'
    method_option :source, type: :string, enum: %w[gemfile binary],
                           desc: 'Source type (gemfile or binary)'
    method_option :interactive, type: :boolean, aliases: '-i', default: false,
                                desc: 'Interactive mode for version selection'
    def local(version = nil)
      cmd = VersionCommand.new
      cmd.options = options
      cmd.local(version)
    end

    desc 'versions', 'List all installed Metanorma versions'
    def versions
      cmd = VersionCommand.new
      cmd.versions
    end

    desc 'available [SOURCE]', 'List available Metanorma versions to install'
    method_option :format, type: :string, aliases: '-f', default: 'text',
                           desc: 'Output format (text or json)'
    def available(source = nil)
      cmd = AvailableCommand.new
      cmd.options = options

      case source
      when 'gemfile' then cmd.gemfile
      when 'binary' then cmd.binary
      when 'all', nil then cmd.all
      else
        puts "Error: Unknown source '#{source}'. Available: gemfile, binary, all"
        exit 1
      end
    end

    desc 'uninstall VERSION', 'Uninstall a Metanorma version'
    method_option :force, type: :boolean, aliases: '-f', default: false,
                          desc: 'Force uninstallation without confirmation'
    def uninstall(version)
      cmd = UninstallCommand.new
      cmd.options = options
      cmd.uninstall(version)
    end

    # General commands
    PLATFORM_REPOSITORIES = {
      'gemfile' => GemfileRepository,
      'snap' => SnapRepository,
      'homebrew' => HomebrewRepository,
      'chocolatey' => ChocolateyRepository
    }.freeze

    desc 'info PLATFORM VERSION', 'Get details for a specific version'
    method_option :format, type: :string, aliases: '-f', default: 'json'
    def info(platform, version_number)
      repo_class = PLATFORM_REPOSITORIES[platform]
      unless repo_class
        puts "Error: Unknown platform '#{platform}'. Available: #{PLATFORM_REPOSITORIES.keys.join(', ')}"
        exit 1
      end

      repo = repo_class.new
      version_obj = repo.find(version_number)

      unless version_obj
        puts "Error: Version '#{version_number}' not found for platform '#{platform}'"
        exit 1
      end

      case options[:format]
      when 'json'
        output = JsonFormatter.format_version(version_obj)
        output['platform'] = platform
        puts JSON.pretty_generate(output)
      else
        puts "#{platform.capitalize} version #{version_obj.display_name}:"
        puts "  Version: #{version_obj.version}"
        puts "  Published: #{version_obj.published_at || 'N/A'}"
        puts "  Parsed: #{version_obj.parsed_at || 'N/A'}"
        version_obj.to_h.each do |k, v|
          next if %w[version published_at parsed_at].include?(k)

          puts "  #{k}: #{v}"
        end
      end
    end

    desc 'list PLATFORM', 'List versions for a platform'
    method_option :format, type: :string, aliases: '-f', default: 'json'
    def list(platform)
      repo_class = PLATFORM_REPOSITORIES[platform]
      unless repo_class
        puts "Error: Unknown platform '#{platform}'. Available: #{PLATFORM_REPOSITORIES.keys.join(', ')}"
        exit 1
      end

      repo = repo_class.new
      versions = repo.all

      case options[:format]
      when 'json'
        output = JsonFormatter.format_versions(versions)
        output['platform'] = platform
        puts JSON.pretty_generate(output)
      else
        puts "#{platform.capitalize} versions (#{versions.size}):"
        versions.each do |v|
          published = v.published_at ? " (#{v.published_at.strftime('%Y-%m-%d')})" : ''
          puts "  #{v.display_name}#{published}"
        end
      end
    end

    desc 'list-all', 'List all versions from all platforms'
    method_option :format, type: :string, aliases: '-f', default: 'json'
    def list_all
      case options[:format]
      when 'json'
        output = {}
        PLATFORM_REPOSITORIES.each do |name, repo_class|
          repo = repo_class.new
          output[name] = JsonFormatter.format_versions(repo.all)
        end

        puts JSON.pretty_generate(output)
      else
        PLATFORM_REPOSITORIES.each_key do |platform|
          list(platform)
        end
      end
    end

    desc 'version', 'Show mnenv version'
    def version
      puts "mnenv #{Mnenv::VERSION}"
    end

    desc 'update', 'Update version data from metanorma/versions repository'
    def update
      puts 'Updating version data...'
      Repository.update_versions
      puts 'Version data updated successfully.'
    end
  end
end
