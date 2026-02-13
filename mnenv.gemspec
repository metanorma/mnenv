# frozen_string_literal: true

require_relative 'lib/mnenv/version'

Gem::Specification.new do |spec|
  spec.name          = 'mnenv'
  spec.version       = Mnenv::VERSION
  spec.authors       = ['Ribose Inc.']
  spec.email         = ['open.source@ribose.com']

  spec.summary       = 'Version discovery and management for Metanorma (mnenv)'
  spec.description   = 'Unified interface for discovering and managing Metanorma ' \
                       'versions from Gemfile (Docker), Snap, Homebrew, and Chocolatey sources. ' \
                       'Provides mnenv CLI command for querying version information.'
  spec.homepage      = 'https://github.com/metanorma/mnenv'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.1'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)}) ||
        f.start_with?('.')
    end
  end
  spec.bindir        = 'exe'
  spec.executables   = ['mnenv']
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'activesupport'
  spec.add_dependency 'lutaml-model', '~> 0.7'
  spec.add_dependency 'lutaml-xsd', '~> 1.0'
  spec.add_dependency 'moxml'
  spec.add_dependency 'nokogiri'
  spec.add_dependency 'paint'
  spec.add_dependency 'thor', '~> 1.0'
  spec.add_dependency 'tty-prompt'
end
