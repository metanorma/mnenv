# frozen_string_literal: true

require 'tty/prompt'
require_relative '../installer'

module Mnenv
  class UninstallCommand < Thor
    namespace :uninstall

    class_option :force, type: :boolean, aliases: '-f', default: false,
                         desc: 'Force uninstallation without confirmation'

    desc 'VERSION', 'Uninstall a specific Metanorma version'
    method_option :force, type: :boolean, aliases: '-f', default: false
    def uninstall(version)
      version_dir = File.expand_path("~/.mnenv/versions/#{version}")

      unless Dir.exist?(version_dir)
        puts "Version #{version} is not installed."
        return
      end

      unless options[:force]
        prompt = TTY::Prompt.new
        unless prompt.yes?("Uninstall Metanorma #{version}? This cannot be undone.")
          puts 'Uninstallation cancelled.'
          return
        end
      end

      FileUtils.rm_rf(version_dir)

      # Regenerate shims
      ShimManager.new.regenerate_all

      puts "Uninstalled Metanorma #{version}"
    rescue StandardError => e
      warn "Error: #{e.message}"
      exit 1
    end
  end
end
