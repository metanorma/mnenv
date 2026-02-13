# frozen_string_literal: true

require_relative 'base'
require_relative 'bash'
require_relative 'power_shell'
require_relative 'cmd'

module Mnenv
  module Shells
    # Factory for detecting and creating shell instances
    class ShellFactory
      SHELLS = {
        'bash' => BashShell,
        'sh' => BashShell,
        'dash' => BashShell,
        'zsh' => BashShell,
        'fish' => BashShell, # Fish can run bash scripts in compatibility mode
        'powershell' => PowerShellShell,
        'pwsh' => PowerShellShell,
        'cmd' => CmdShell
      }.freeze

      class << self
        # Detect the current shell from environment
        def detect
          shell_env = ENV['SHELL'] || ENV['COMSPEC'] || ''

          if windows?
            detect_windows_shell(shell_env)
          else
            detect_unix_shell(shell_env)
          end
        end

        # Get shell by name
        def get(shell_name)
          shell_class = SHELLS[shell_name.downcase]
          raise ArgumentError, "Unknown shell: #{shell_name}" unless shell_class

          shell_class.new
        end

        # Get all shells for the current platform
        def platform_shells
          if windows?
            [PowerShellShell.new, CmdShell.new]
          else
            [BashShell.new]
          end
        end

        private

        def windows?
          RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
        end

        def detect_unix_shell(shell_env)
          # Extract shell name from path
          shell_name = File.basename(shell_env) if shell_env

          # Default to bash if we can't determine
          shell_name ||= 'bash'

          get(shell_name)
        rescue ArgumentError
          # Default to bash for unknown shells
          BashShell.new
        end

        def detect_windows_shell(comspec)
          if comspec =~ /powershell|pwsh/i
            PowerShellShell.new
          else
            # Default to CMD on Windows, but also create PowerShell shim
            CmdShell.new
          end
        end
      end
    end
  end
end
