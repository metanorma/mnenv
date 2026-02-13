# frozen_string_literal: true

module Mnenv
  autoload :GemfileCommand, 'mnenv/commands/gemfile_command'
  autoload :SnapCommand, 'mnenv/commands/snap_command'
  autoload :HomebrewCommand, 'mnenv/commands/homebrew_command'
  autoload :ChocolateyCommand, 'mnenv/commands/chocolatey_command'
  autoload :InstallCommand, 'mnenv/commands/install_command'
  autoload :VersionCommand, 'mnenv/commands/version_command'
  autoload :UninstallCommand, 'mnenv/commands/uninstall_command'
end
