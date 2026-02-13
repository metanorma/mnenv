# frozen_string_literal: true

require_relative 'base'

module Mnenv
  module Shells
    # PowerShell shell implementation (Windows)
    class PowerShellShell < BaseShell
      def name
        'powershell'
      end

      def shim_extension
        '.ps1'
      end

      def shim_content(executable_name)
        <<~SHIM
          # mnenv shim for PowerShell
          $ErrorActionPreference = "Stop"

          $MNENV_ROOT = if ($env:MNENV_ROOT) { $env:MNENV_ROOT } else { "$env:USERPROFILE\\.mnenv" }

          # Resolve version and source using mnenv resolver
          $versionFile = "$MNENV_ROOT\\version"
          $sourceFile = "$MNENV_ROOT\\source"

          # Check environment variables first
          $VERSION = $env:MNENV_VERSION
          $SOURCE = $env:MNENV_SOURCE

          # Check local .metanorma-version file
          if (-not $VERSION) {
            $dir = Get-Location
            while ($dir -and $dir.Path -ne $dir.Root) {
              $localVersionFile = Join-Path $dir ".metanorma-version"
              if (Test-Path $localVersionFile) {
                $VERSION = Get-Content $localVersionFile -Raw
                $VERSION = $VERSION.Trim()
                break
              }
              $localSourceFile = Join-Path $dir ".metanorma-source"
              if (-not $SOURCE -and (Test-Path $localSourceFile)) {
                $SOURCE = Get-Content $localSourceFile -Raw
                $SOURCE = $SOURCE.Trim()
              }
              $dir = Split-Path $dir -Parent
            }
          }

          # Check global version file
          if (-not $VERSION -and (Test-Path $versionFile)) {
            $VERSION = Get-Content $versionFile -Raw
            $VERSION = $VERSION.Trim()
          }

          if (-not $SOURCE -and (Test-Path $sourceFile)) {
            $SOURCE = Get-Content $sourceFile -Raw
            $SOURCE = $SOURCE.Trim()
          }

          # Default source
          if (-not $SOURCE) {
            $SOURCE = "gemfile"
          }

          if (-not $VERSION) {
            Write-Error "mnenv: version not set or invalid"
            Write-Error "Set a version with: mnenv global <version> or mnenv local <version>"
            exit 1
          }

          # Determine executable path based on source
          if ($SOURCE -eq "binary") {
            $EXECUTABLE = "$MNENV_ROOT\\versions\\$VERSION\\metanorma.exe"
          } else {
            # Bundler creates .cmd files on Windows, not .bat
            $EXECUTABLE = "$MNENV_ROOT\\versions\\$VERSION\\bin\\#{executable_name}.cmd"
          }

          if (-not (Test-Path $EXECUTABLE)) {
            Write-Error "mnenv: #{executable_name} not installed for version $VERSION (source: $SOURCE)"
            Write-Error "Install it with: mnenv install $VERSION --source $SOURCE"
            exit 1
          }

          & $EXECUTABLE $args
        SHIM
      end

      def use_output(version, source)
        lines = []
        lines << "$env:MNENV_VERSION = '#{version}'"
        lines << "$env:MNENV_SOURCE = '#{source}'" if source
        lines << '# Run this in your PowerShell session'
        lines.join("\n")
      end

      def config_file
        File.expand_path('~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1')
      end

      def windows?
        true
      end
    end
  end
end
