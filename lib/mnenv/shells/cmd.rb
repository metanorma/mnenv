# frozen_string_literal: true

require_relative 'base'

module Mnenv
  module Shells
    # CMD/Batch shell implementation (Windows)
    class CmdShell < BaseShell
      def name
        'cmd'
      end

      def shim_extension
        '.bat'
      end

      def shim_content(executable_name)
        <<~SHIM
          @echo off
          rem mnenv shim for CMD

          if defined MNENV_ROOT (
            set "MNENV_ROOT=%MNENV_ROOT%"
          ) else (
            set "MNENV_ROOT=%USERPROFILE%\\.mnenv"
          )

          rem Resolve version and source
          set "VERSION="
          set "SOURCE="

          rem Check environment variables first
          if defined MNENV_VERSION set "VERSION=%MNENV_VERSION%"
          if defined MNENV_SOURCE set "SOURCE=%MNENV_SOURCE%"

          rem Check local .metanorma-version file
          if not defined VERSION (
            set "DIR=%CD%"
            :loop
            if exist "%DIR%\\.metanorma-version" (
              set /p VERSION=<"%DIR%\\.metanorma-version"
              goto :found_version
            )
            for %%I in ("%DIR%\\..") do set "PARENT=%%~fI"
            if "%PARENT%"=="%DIR%" goto :check_global
            set "DIR=%PARENT%"
            goto :loop
          )

          :check_global
          if not defined VERSION (
            if exist "%MNENV_ROOT%\\version" (
              set /p VERSION=<"%MNENV_ROOT%\\version"
            )
          )

          :found_version
          if not defined SOURCE (
            if exist "%MNENV_ROOT%\\source" (
              set /p SOURCE=<"%MNENV_ROOT%\\source"
            )
          )

          rem Default source
          if not defined SOURCE set "SOURCE=gemfile"

          if not defined VERSION (
            echo mnenv: version not set or invalid 1>&2
            echo Set a version with: mnenv global ^<version^> or mnenv local ^<version^> 1>&2
            exit /b 1
          )

          rem Determine executable path based on source
          if "%SOURCE%"=="binary" (
            set "EXECUTABLE=%MNENV_ROOT%\\versions\\%VERSION%\\metanorma.exe"
          ) else (
            set "EXECUTABLE=%MNENV_ROOT%\\versions\\%VERSION%\\bin\\#{executable_name}.cmd"
          )

          if not exist "%EXECUTABLE%" (
            echo mnenv: #{executable_name} not installed for version %VERSION% ^(source: %SOURCE%^) 1>&2
            echo Install it with: mnenv install %VERSION% --source %SOURCE% 1>&2
            exit /b 1
          )

          call "%EXECUTABLE%" %*
        SHIM
      end

      def use_output(version, source)
        lines = []
        lines << "set MNENV_VERSION=#{version}"
        lines << "set MNENV_SOURCE=#{source}" if source
        lines << 'rem Run this in your CMD session'
        lines.join("\n")
      end

      def config_file
        nil # CMD doesn't have a standard config file
      end

      def windows?
        true
      end
    end
  end
end
