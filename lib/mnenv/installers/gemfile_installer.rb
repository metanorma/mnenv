# frozen_string_literal: true

require_relative '../installer/base'

module Mnenv
  module Installers
    class GemfileInstaller < Installer
      def verify_prerequisites!
        verify_version_exists!
        verify_development_tools!
      end

      def perform_installation
        copy_gemfiles
        bundle_install
      end

      private

      def verify_version_exists!
        repo = GemfileRepository.new
        return if repo.exists?(version)

        available = repo.all.map(&:display_name).join(', ')
        raise InstallationError, "Version #{version} not found in Gemfile repository. " \
                                "Available: #{available}"
      end

      def verify_development_tools!
        required_tools = %w[ruby bundle]

        # Use 'where' on Windows, 'which' on Unix
        which_cmd = Gem.win_platform? ? 'where' : 'which'

        missing_tools = required_tools.reject do |tool|
          system(which_cmd, tool, out: File::NULL, err: File::NULL)
        end

        return if missing_tools.empty?

        raise DevelopmentToolsMissing,
              "Development tools required for Gemfile installation.\n" \
              "Missing: #{missing_tools.join(', ')}\n" \
              "Install with: apt-get install ruby bundler build-essential  # Debian/Ubuntu\n" \
              "             brew install ruby bundler                       # macOS\n" \
              "Or use: mnenv install #{version} --source=binary"
      end

      def copy_gemfiles
        repo = GemfileRepository.new
        version_obj = repo.find(version)

        raise InstallationError, "Version #{version} not found" unless version_obj

        gemfile_source = version_obj.gemfile_path_calc
        gemfile_lock_source = version_obj.gemfile_lock_path_calc

        raise InstallationError, "Gemfile not found for #{version}" unless File.exist?(gemfile_source)
        raise InstallationError, "Gemfile.lock not found for #{version}" unless File.exist?(gemfile_lock_source)

        FileUtils.cp(gemfile_source, File.join(version_dir, 'Gemfile'))
        FileUtils.cp(gemfile_lock_source, File.join(version_dir, 'Gemfile.lock'))
      end

      def bundle_install
        Dir.chdir(version_dir) do
          # Use system with bundler for proper isolation
          # Don't suppress output to help debug issues
          unless system('bundle', 'install', '--path', '.bundle', '--binstubs', 'bin')
            raise InstallationError, "Bundle install failed for #{version}"
          end
        end
      end
    end
  end
end
