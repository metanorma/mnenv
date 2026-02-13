# One-line installer for mnenv (Windows)
# Install: Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/metanorma/mnenv/main/bin/Install-Mnenv.ps1'))

# Copyright 2024 Metanorma mnenv project
# Licensed under Apache License 2.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$MnenvRoot = $env:MNENV_ROOT,

    [Parameter(Mandatory = $false)]
    [string]$RepoUrl = "https://github.com/metanorma/mnenv"
)

$ErrorActionPreference = "Stop"

# Set TLS 1.2 (required for GitHub)
try {
    Write-Host "Forcing web requests to allow TLS v1.2 (Required for GitHub)"
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
}
catch {
    Write-Warning "Unable to set TLS 1.2. Installation may fail on older systems."
}

function Get-Downloader {
    param(
        [string]$Url,
        [string]$ProxyUrl
    )

    $downloader = New-Object System.Net.WebClient
    $defaultCreds = [System.Net.CredentialCache]::DefaultCredentials
    if ($defaultCreds) {
        $downloader.Credentials = $defaultCreds
    }

    if ($ProxyUrl) {
        Write-Host "Using proxy server: $ProxyUrl"
        $proxy = New-Object System.Net.WebProxy -ArgumentList $ProxyUrl, $true
        $proxy.Credentials = $defaultCreds
        if (-not $proxy.IsBypassed($Url)) {
            $downloader.Proxy = $proxy
        }
    }

    $downloader
}

function Test-MnenvInstalled {
    $checkPath = if ($MnenvRoot) { $MnenvRoot } else { Join-Path $env:USERPROFILE ".mnenv" }

    if (Test-Path $checkPath) {
        $files = Get-ChildItem $checkPath -ErrorAction SilentlyContinue
        if ($files) {
            Write-Warning "Files from a previous mnenv installation were found at '$checkPath'."
            Write-Host "To reinstall, remove the directory and run this script again."
            return $true
        }
    }
    $false
}

function Main {
    $actualMnenvRoot = if ($MnenvRoot) { $MnenvRoot } else { Join-Path $env:USERPROFILE ".mnenv" }

    Write-Host "==> Installing mnenv to $actualMnenvRoot"

    # Check for existing installation
    if (Test-MnenvInstalled) {
        Write-Host "Existing installation detected. Aborting."
        Write-Host "To reinstall, first remove: $actualMnenvRoot"
        return
    }

    # Clone or update repository
    if (Test-Path $actualMnenvRoot) {
        Write-Host "==> Updating existing installation"
        Set-Location $actualMnenvRoot
        & git pull
    }
    else {
        Write-Host "==> Cloning repository from $RepoUrl"
        & git clone $RepoUrl $actualMnenvRoot
    }

    # Create directory structure
    $versionsDir = Join-Path $actualMnenvRoot "versions"
    $shimsDir = Join-Path $actualMnenvRoot "shims"
    $cacheDir = Join-Path $actualMnenvRoot "cache"
    $completionsDir = Join-Path $actualMnenvRoot "completions"

    @($versionsDir, $shimsDir, $cacheDir, $completionsDir) | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
    }

    # Setup PowerShell profile
    Setup-PowerShell $actualMnenvRoot

    Write-Host "==> Installation complete!"
    Write-Host "==> Reload your shell: . `$PROFILE"
    Write-Host "==> Then run: mnenv install --list"
}

function Setup-PowerShell {
    param([string]$RootPath)

    $profilePath = $PROFILE.CurrentUserCurrentHost
    $shimsPath = Join-Path $RootPath "shims"
    $completionsPath = Join-Path $RootPath "completions\powershell.ps1"
    $initLine = "`$env:PATH = `"$shimsPath;`$env:PATH`""
    $completionLine = ". `"$completionsPath`""

    # Ensure profile exists
    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }

    $profileContent = Get-Content $profilePath -Raw

    # Add shims to PATH if not already present
    if ($profileContent -notlike "*$shimsPath*") {
        Add-Content $profilePath "`n# Mnenv"
        Add-Content $profilePath $initLine
        Write-Host "==> Added mnenv shims to PATH in $profilePath"
    }

    # Add completion if not already present
    if ($profileContent -notlike "*$completionsPath*") {
        Add-Content $profilePath $completionLine
        Write-Host "==> Added mnenv completion to $profilePath"
    }
}

try {
    Main
}
catch {
    Write-Error "Installation failed: $_"
    Write-Host "For help, visit: https://github.com/metanorma/mnenv"
    exit 1
}
