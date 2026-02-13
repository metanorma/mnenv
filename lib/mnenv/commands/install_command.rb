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

    desc 'VERSION', 'Install a specific Metanorma version'
    method_option :source, type: :string, enum: %w[gemfile binary], default: 'gemfile',
                           desc: 'Installation source (gemfile or binary)'
    method_option :interactive, type: :boolean, aliases: '-i', default: false,
                                desc: 'Interactive mode for version selection'
    method_option :list, type: :boolean, aliases: '-l', default: false,
                         desc: 'List all available Metanorma versions'
    def install(version = nil)
      # If --list flag is provided, show available versions and exit
      return list_available_versions if options[:list]

      # If no version provided or interactive mode, prompt for selection
      if options[:interactive] || version.nil?
        version, source = select_installation_interactive
      else
        source = options[:source]
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

    def list_available_versions
      current_version, current_source = resolve_current
      current_platform = detect_platform

      puts "\nAvailable Metanorma versions:"
      puts "(gemfile = source build, binary = prebuilt for specific platforms)\n"

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
        all_versions[v.version][:binary_platforms] = extract_platforms(v.assets)
      end

      # Check what's installed (from installed directory, not versions data)
      if Dir.exist?(Paths::INSTALLED_DIR)
        Dir.glob("#{Paths::INSTALLED_DIR}/*/").each do |dir|
          version = File.basename(dir)
          source_file = File.join(dir, 'source')
          source = File.exist?(source_file) ? File.read(source_file).strip : nil
          all_versions[version][:"installed_#{source}"] = true if source && all_versions[version]
        end
      end

      # Display sorted versions (newest first)
      all_versions.sort.reverse.each do |version, info|
        # Build sources string with platform info for binary
        sources = []
        sources << 'gemfile' if info[:gemfile]
        if info[:binary]
          platforms = info[:binary_platforms] || []
          if platforms.any?
            # Highlight current platform
            platform_display = platforms.map do |p|
              p == current_platform ? "#{p}*" : p
            end.join(', ')
            sources << "binary [#{platform_display}]"
          else
            sources << 'binary'
          end
        end

        # Check if current
        is_current = version == current_version && sources.any? { |s| s.include?(current_source.to_s) }
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
      puts '  * Current version / platform'
      puts '  [installed: ...] = Already installed locally'
      puts "  Detected platform: #{current_platform}"
      puts "\nInstall with: mnenv install VERSION --source SOURCE"
      puts 'Examples:'
      puts '  mnenv install 1.14.4 --source gemfile'
      puts '  mnenv install 1.14.4 --source binary'
    end

    def extract_platforms(assets)
      return [] unless assets

      assets.filter_map do |asset|
        # Match patterns like metanorma-darwin-arm64.tgz or metanorma-linux-x86_64.tgz
        case asset
        when /darwin/ then 'macos'
        when /linux/ then 'linux'
        when /windows/ then 'windows'
        end
      end.uniq.sort
    end

    def detect_platform
      case RbConfig::CONFIG['host_os']
      when /linux/ then 'linux'
      when /darwin/ then 'macos'
      when /mswin|mingw|cygwin/ then 'windows'
      else 'unknown'
      end
    end

    def resolve_current
      # Get current version
      version = ENV['METANORMA_VERSION']
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
        version ||= (File.read(Paths::VERSION_FILE).strip if File.exist?(Paths::VERSION_FILE))

      end

      # Get current source
      source = ENV['METANORMA_SOURCE']
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
        source ||= (File.read(Paths::SOURCE_FILE).strip if File.exist?(Paths::SOURCE_FILE))

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
        version_dir = Paths.version_install_dir(v.version)
        installed = Dir.exist?(version_dir) && File.exist?(File.join(version_dir, 'source'))
        installed_source = if installed
                             src = File.read(File.join(version_dir, 'source')).strip
                             src.empty? ? '' : "(#{src})"
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
