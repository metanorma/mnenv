# frozen_string_literal: true

require 'tty/prompt'
require_relative '../installer'
require_relative '../binary_repository'

module Mnenv
  class InstallCommand < Thor
    namespace :install

    class_option :source, type: :string, enum: %w[gemfile binary], default: 'gemfile',
                          desc: 'Installation source (gemfile or binary)'
    class_option :interactive, type: :boolean, aliases: '-i', default: false,
                               desc: 'Interactive mode for version selection'

    desc '--list', 'List all available Metanorma versions'
    def list
      current_version, current_source = resolve_current

      puts "\nAvailable Metanorma versions:"
      puts "(Sources: gemfile = RubyGems, binary = packed-mn binary)\n"

      # Get all unique versions from both sources
      gemfile_repo = GemfileRepository.new
      binary_repo = BinaryRepository.new

      gemfile_versions = gemfile_repo.all.sort.reverse
      binary_versions = binary_repo.all

      # Combine all versions
      all_versions = Hash.new { |h, k| h[k] = { gemfile: false, binary: false } }

      gemfile_versions.each do |v|
        all_versions[v.version][:gemfile] = true
        all_versions[v.version][:gemfile_obj] = v
      end

      binary_versions.each do |v|
        all_versions[v.version][:binary] = true
        all_versions[v.version][:binary_obj] = v
      end

      # Check what's installed
      versions_dir = File.expand_path('~/.mnenv/versions')
      if Dir.exist?(versions_dir)
        Dir.glob("#{versions_dir}/*/").each do |dir|
          version = File.basename(dir)
          source_file = File.join(dir, 'source')
          source = File.exist?(source_file) ? File.read(source_file).strip : 'unknown'
          all_versions[version][:"installed_#{source}"] = true if all_versions[version]
        end
      end

      # Display sorted versions (newest first)
      all_versions.sort.reverse.each do |version, info|
        # Build sources string
        sources = []
        sources << 'gemfile' if info[:gemfile]
        sources << 'binary' if info[:binary]

        # Check if current
        is_current = version == current_version && sources.include?(current_source)
        marker = is_current ? '* ' : '  '

        # Version display
        version_display = version.ljust(15)

        # Sources display
        sources_display = sources.join(', ')

        # Installed status
        installed = []
        installed << 'gemfile' if info[:installed_gemfile]
        installed << 'binary' if info[:installed_binary]
        installed_display = installed.empty? ? '' : " [installed: #{installed.join(', ')}]"

        puts "  #{marker}#{version_display}(#{sources_display})#{installed_display}"
      end

      # Legend
      puts "\nLegend:"
      puts '  * Current version'
      puts '  [installed: ...] = Already installed locally'
      puts "\nInstall with: mnenv install VERSION --source SOURCE"
      puts 'Examples:'
      puts '  mnenv install 1.14.4 --source gemfile'
      puts '  mnenv install 1.14.4 --source binary'
    end

    desc 'VERSION', 'Install a specific Metanorma version'
    method_option :source, type: :string, enum: %w[gemfile binary], default: 'gemfile'
    method_option :interactive, type: :boolean, aliases: '-i', default: false
    def install(version = nil, _options = nil)
      opts = _options || options
      if opts[:interactive] || version.nil?
        version, source = select_installation_interactive
      else
        source = opts[:source]
      end

      installer = InstallerFactory.create(version, source: source)

      if installer.installed?
        prompt = TTY::Prompt.new
        unless prompt.yes?("Version #{version} (source: #{source}) is already installed. Reinstall?")
          puts 'Installation cancelled.'
          return
        end
      end

      puts "Installing Metanorma #{version} (source: #{source})..."
      installer.install
      puts "Successfully installed Metanorma #{version} (source: #{source})!"
    rescue Installer::InstallationError => e
      warn "Error: #{e.message}"
      exit 1
    end

    default_task :install

    private

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

    def select_installation_interactive
      repo = GemfileRepository.new
      prompt = TTY::Prompt.new

      # First, select source
      source = prompt.select('Select installation source:', [
                               { name: 'Gemfile (faster, on-demand loading, requires dev tools, upgradable)',
                                 value: 'gemfile' },
                               { name: 'Binary (slower, full-stack memory load, no dev tools, fixed)',
                                 value: 'binary' }
                             ])

      # Then, select version
      choices = repo.all.sort.map do |v|
        installed = Dir.exist?(File.expand_path("~/.mnenv/versions/#{v.version}"))
        installed_source = if installed
                             source_file = File.expand_path("~/.mnenv/versions/#{v.version}/source")
                             File.exist?(source_file) ? "(#{File.read(source_file).strip})" : ''
                           else
                             ''
                           end
        { name: "#{v.display_name} #{installed ? "[installed: #{installed_source}]" : ''}", value: v.version }
      end

      version = prompt.select('Select a version to install:', choices)

      [version, source]
    end
  end
end
