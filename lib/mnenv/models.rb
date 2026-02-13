# frozen_string_literal: true

require 'lutaml/model'

module Mnenv
  autoload :ArtifactVersion, 'mnenv/models/version'
  autoload :GemfileVersion, 'mnenv/models/gemfile_version'
  autoload :SnapVersion, 'mnenv/models/snap_version'
  autoload :HomebrewVersion, 'mnenv/models/homebrew_version'
  autoload :ChocolateyVersion, 'mnenv/models/chocolatey_version'
end
