# Mnenv PowerShell completion
# Add this to your $PROFILE: . "$env:USERPROFILE\.mnenv\completions\powershell.ps1"

if ($null -eq (Get-Command Register-ArgumentCompleter -ErrorAction SilentlyContinue)) {
    # PowerShell 5.0 or earlier - use old-style completion
    function mnenvCompletion {
        param($commandName, $wordToComplete, $cursorPosition)

        $commands = @('install', 'use', 'global', 'local', 'versions', 'uninstall', 'help',
                     'gemfile', 'snap', 'homebrew', 'chocolatey', 'info', 'list', 'list-all', 'version')

        # Get installed versions
        $versionsDir = Join-Path $env:USERPROFILE ".mnenv\versions"
        if (Test-Path $versionsDir) {
            $versions = Get-ChildItem $versionsDir -Directory | Select-Object -ExpandProperty Name
        } else {
            $versions = @()
        }

        # Command completion
        $commandLine = $wordToComplete
        $commandParts = $commandLine -split '\s+'
        $commandCount = $commandParts.Count

        if ($commandCount -eq 1 -or $commandLine.Trim().EndsWith(' ')) {
            # Completing command
            $commands | Where-Object { $_ -like "$wordToComplete*" }
        }
        # Subcommand completion
        elseif ($commandCount -eq 2) {
            $subcommand = $commandParts[1]

            switch ($subcommand) {
                { $_ -in @('install', 'use', 'global', 'local', 'uninstall') } {
                    $versions | Where-Object { $_ -like "$wordToComplete*" }
                }
                default {
                    @()
                }
            }
        }
        else {
            @()
        }
    }

    Register-ArgumentCompleter -CommandName 'mnenv' -ScriptBlock $function:mnenvCompletion
}
else {
    # PowerShell 6+ - use modern completion
    $script:block = {
        param($wordToComplete, $commandAst, $cursorPosition)

        $commands = @('install', 'use', 'global', 'local', 'versions', 'uninstall', 'help',
                     'gemfile', 'snap', 'homebrew', 'chocolatey', 'info', 'list', 'list-all', 'version')

        # Get installed versions
        $versionsDir = Join-Path $env:USERPROFILE ".mnenv\versions"
        if (Test-Path $versionsDir) {
            $versions = Get-ChildItem $versionsDir -Directory | Select-Object -ExpandProperty Name
        } else {
            $versions = @()
        }

        # Command completion
        if ($commandAst.CommandElements.Count -eq 1) {
            $commands | Where-Object { $_ -like "$wordToComplete*" }
        }
        # Subcommand completion
        elseif ($commandAst.CommandElements.Count -eq 2) {
            $subcommand = $commandAst.CommandElements[1].Value

            switch ($subcommand) {
                { $_ -in @('install', 'use', 'global', 'local', 'uninstall') } {
                    $versions | Where-Object { $_ -like "$wordToComplete*" }
                }
                default {
                    @()
                }
            }
        }
        else {
            @()
        }
    }

    Register-ArgumentCompleter -CommandName 'mnenv' -ScriptBlock $script:block
}

# Add ~/.mnenv/shims to PATH if not already present
$shimsPath = Join-Path $env:USERPROFILE ".mnenv\shims"
if ($env:PATH -notlike "*$shimsPath*") {
    $env:PATH = "$shimsPath;$env:PATH"
}
