# frozen_string_literal: true

require 'tty/prompt'
require_relative '../installer'

module Mnenv
  class UninstallCommand < Thor
    namespace :uninstall

    class_option :source, type: :string, enum: %w[gemfile binary],
                          desc: 'Source type to uninstall (gemfile or binary). If not specified, uninstalls all sources.'
    class_option :force, type: :boolean, aliases: '-f', default: false,
                         desc: 'Force uninstallation without confirmation'

    desc 'VERSION', 'Uninstall a specific Metanorma version'
    method_option :source, type: :string, enum: %w[gemfile binary]
    method_option :force, type: :boolean, aliases: '-f', default: false
    def uninstall(version)
      source = options[:source]

      if source
        # Uninstall specific source
        uninstall_source(version, source)
      else
        # Uninstall all sources for this version
        uninstall_all_sources(version)
      end

      # Regenerate shims after uninstallation
      ShimManager.new.regenerate_all
    rescue StandardError => e
      warn "Error: #{e.message}"
      exit 1
    end

    private

    def uninstall_source(version, source)
      version_dir = Paths.version_install_dir(version, source)

      unless Dir.exist?(version_dir)
        puts "Version #{version} (source: #{source}) is not installed."
        return
      end

      confirm_and_remove(version, source, version_dir)
    end

    def uninstall_all_sources(version)
      # Find all installed sources for this version
      installed_sources = find_installed_sources(version)

      if installed_sources.empty?
        puts "Version #{version} is not installed."
        return
      end

      if installed_sources.length == 1
        # Only one source, uninstall directly
        source = installed_sources.first
        version_dir = Paths.version_install_dir(version, source)
        confirm_and_remove(version, source, version_dir)
      else
        # Multiple sources, ask which to uninstall
        puts "Version #{version} has multiple sources installed:"
        installed_sources.each do |src|
          puts "  - #{src}"
        end
        puts ''

        prompt = TTY::Prompt.new
        choices = installed_sources.map { |s| { name: s, value: s } }
        choices << { name: 'All sources', value: 'all' }

        selected = prompt.select('Which source(s) to uninstall?', choices)

        if selected == 'all'
          installed_sources.each do |src|
            version_dir = Paths.version_install_dir(version, src)
            confirm_and_remove(version, src, version_dir, skip_confirm: options[:force])
          end
        else
          version_dir = Paths.version_install_dir(version, selected)
          confirm_and_remove(version, selected, version_dir)
        end
      end
    end

    def find_installed_sources(version)
      sources = []
      %w[gemfile binary].each do |source|
        version_dir = Paths.version_install_dir(version, source)
        sources << source if Dir.exist?(version_dir)
      end
      sources
    end

    def confirm_and_remove(version, source, version_dir, skip_confirm: false)
      unless skip_confirm || options[:force]
        prompt = TTY::Prompt.new
        unless prompt.yes?("Uninstall Metanorma #{version} (#{source})? This cannot be undone.")
          puts 'Uninstallation cancelled.'
          return
        end
      end

      FileUtils.rm_rf(version_dir)
      puts "Uninstalled Metanorma #{version} (source: #{source})"
    end
  end
end
