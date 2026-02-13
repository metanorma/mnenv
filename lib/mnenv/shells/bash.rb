# frozen_string_literal: true

require_relative 'base'

module Mnenv
  module Shells
    # Bash shell implementation (also works for sh, dash, zsh)
    class BashShell < BaseShell
      def name
        'bash'
      end

      def shim_extension
        '' # No extension for bash scripts
      end

      def shim_content(executable_name)
        <<~SHIM
          #!/bin/bash
          set -e

          export MNENV_ROOT="${MNENV_ROOT:-$HOME/.mnenv}"

          # Resolve version and source using mnenv resolver
          VERSION="$("$MNENV_ROOT/lib/mnenv/resolver" "version")"
          SOURCE="$("$MNENV_ROOT/lib/mnenv/resolver" "source")"

          if [ -z "$VERSION" ]; then
            echo "mnenv: version not set or invalid" >&2
            echo "Set a version with: mnenv global <version> or mnenv local <version>" >&2
            exit 1
          fi

          if [ -z "$SOURCE" ]; then
            echo "mnenv: source not set or invalid" >&2
            exit 1
          fi

          # Determine executable path based on source
          if [ "$SOURCE" = "binary" ]; then
            # Binary: single self-contained binary
            EXECUTABLE="$MNENV_ROOT/versions/$VERSION/metanorma"
          else
            # Gemfile: binstub from bundle install
            EXECUTABLE="$MNENV_ROOT/versions/$VERSION/bin/#{executable_name}"
          fi

          if [ ! -f "$EXECUTABLE" ]; then
            echo "mnenv: #{executable_name} not installed for version $VERSION (source: $SOURCE)" >&2
            echo "Install it with: mnenv install $VERSION --source $SOURCE" >&2
            exit 1
          fi

          exec "$EXECUTABLE" "$@"
        SHIM
      end

      def use_output(version, source)
        lines = []
        lines << "export MNENV_VERSION=#{version}"
        lines << "export MNENV_SOURCE=#{source}" if source
        lines << "# Run this in your shell, or use: eval \"$(mnenv use #{version}#{" --source #{source}" if source})\""
        lines.join("\n")
      end

      def config_file
        File.expand_path('~/.bashrc')
      end
    end
  end
end
