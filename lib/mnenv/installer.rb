# frozen_string_literal: true

module Mnenv
  autoload :Installer, 'mnenv/installer/base'
  autoload :InstallerFactory, 'mnenv/installer/factory'
  autoload :ShimManager, 'mnenv/shim_manager'

  module Installers
    autoload :GemfileInstaller, 'mnenv/installers/gemfile_installer'
    autoload :BinaryInstaller, 'mnenv/installers/binary_installer'
  end
end
