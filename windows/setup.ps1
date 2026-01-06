<#
.SYNOPSIS
    CCProxy PowerShell Setup Script

.DESCRIPTION
    Installs or updates CCProxy for Windows PowerShell.
    - Fresh install: Creates config directory, copies templates, sets up profile
    - Update: Updates system files, preserves user config files

.PARAMETER Update
    Update mode - only updates system files, preserves user configs

.PARAMETER Force
    Force overwrite of all files (use with caution)

.PARAMETER Check
    Check current installation status without making changes

.EXAMPLE
    .\setup.ps1
    Fresh installation with interactive prompts

.EXAMPLE
    .\setup.ps1 -Update
    Update system files, preserve user configs

.EXAMPLE
    .\setup.ps1 -Check
    Show installation status

.NOTES
    Author: CCProxy PowerShell
    Version: 1.1.0
    Platform: Windows PowerShell 7+
#>

param(
    [switch]$Update,
    [switch]$Force,
    [switch]$Check,
    [switch]$Help
)

# Script directory
$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$script:ConfigDir = "$env:USERPROFILE\.ccproxy"
$script:Version = "1.1.0"

# Colors
$script:Colors = @{
    Reset  = "`e[0m"
    Bright = "`e[1m"
    Dim    = "`e[2m"
    Green  = "`e[32m"
    Yellow = "`e[33m"
    Blue   = "`e[34m"
    Cyan   = "`e[36m"
    Red    = "`e[31m"
}

# File classifications
$script:UserFiles = @(
    "ccproxy.yaml",
    "config.yaml",
    ".env"
)

$script:SystemFiles = @(
    "watchdog.ps1",
    "show-models.ps1"
)

$script:TemplateFiles = @(
    @{ Source = "ccproxy.yaml"; Target = "ccproxy.yaml"; Template = $true },
    @{ Source = "config.yaml"; Target = "config.yaml"; Template = $true },
    @{ Source = ".env.example"; Target = ".env"; Template = $true }
)

$script:DocFiles = @(
    "README.md",
    "LICENSE",
    ".gitignore",
    "Microsoft.PowerShell_profile.example.ps1",
    ".env.example",
    "docs/AGENT-ROUTING.md",
    "docs/PROVIDERS.md",
    "docs/ROUTING-RULES.md",
    "docs/TROUBLESHOOTING.md",
    "docs/MODELS-COMMAND.md"
)

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host ($Colors.Cyan + ("=" * 60) + $Colors.Reset)
    Write-Host ($Colors.Bright + $Colors.Cyan + "  $Text" + $Colors.Reset)
    Write-Host ($Colors.Cyan + ("=" * 60) + $Colors.Reset)
    Write-Host ""
}

function Write-Section {
    param([string]$Text)
    Write-Host ""
    Write-Host ($Colors.Yellow + ("-" * 40) + $Colors.Reset)
    Write-Host ($Colors.Bright + "  $Text" + $Colors.Reset)
    Write-Host ($Colors.Yellow + ("-" * 40) + $Colors.Reset)
}

function Write-Success {
    param([string]$Text)
    Write-Host ($Colors.Green + "[OK] $Text" + $Colors.Reset)
}

function Write-Warning {
    param([string]$Text)
    Write-Host ($Colors.Yellow + "[!] $Text" + $Colors.Reset)
}

function Write-Error {
    param([string]$Text)
    Write-Host ($Colors.Red + "[X] $Text" + $Colors.Reset)
}

function Write-Info {
    param([string]$Text)
    Write-Host ($Colors.Dim + "    $Text" + $Colors.Reset)
}

function Write-Skip {
    param([string]$Text)
    Write-Host ($Colors.Blue + "[SKIP] $Text" + $Colors.Reset)
}

function Show-Help {
    Write-Header "CCProxy PowerShell Setup"
    Write-Host "  Usage: .\setup.ps1 [options]"
    Write-Host ""
    Write-Host "  Options:"
    Write-Host "    -Check      Show installation status"
    Write-Host "    -Update     Update system files only (preserves configs)"
    Write-Host "    -Force      Force overwrite all files"
    Write-Host "    -Help       Show this help message"
    Write-Host ""
    Write-Host "  File Types:"
    Write-Host "    User Config (never overwritten on update):"
    Write-Host "      - ccproxy.yaml   Your routing rules and OAuth config"
    Write-Host "      - config.yaml    Your API keys and model deployments"
    Write-Host "      - .env           Your environment variables"
    Write-Host ""
    Write-Host "    System Files (updated automatically):"
    Write-Host "      - watchdog.ps1   Auto-restart on crash"
    Write-Host "      - docs/*         Documentation"
    Write-Host ""
    Write-Host "  Examples:"
    Write-Host "    .\setup.ps1           # Fresh install"
    Write-Host "    .\setup.ps1 -Update   # Update system files only"
    Write-Host "    .\setup.ps1 -Check    # Check status"
    Write-Host ""
}

function Test-ExistingInstall {
    return (Test-Path "$script:ConfigDir\ccproxy.yaml")
}

function Get-InstalledVersion {
    $versionFile = "$script:ConfigDir\.version"
    if (Test-Path $versionFile) {
        return Get-Content $versionFile -Raw
    }
    return "unknown"
}

function Show-Status {
    Write-Header "CCProxy Installation Status"

    $installed = Test-ExistingInstall
    $version = Get-InstalledVersion

    Write-Host "  Config Directory: $script:ConfigDir"
    Write-Host "  Installed: $(if ($installed) { 'Yes' } else { 'No' })"
    Write-Host "  Installed Version: $version"
    Write-Host "  Script Version: $script:Version"
    Write-Host ""

    if ($installed) {
        Write-Section "User Config Files"
        foreach ($file in $script:UserFiles) {
            $path = Join-Path $script:ConfigDir $file
            if (Test-Path $path) {
                $size = (Get-Item $path).Length
                Write-Success "$file ($size bytes)"
            } else {
                Write-Warning "$file (not found)"
            }
        }

        Write-Section "System Files"
        foreach ($file in $script:SystemFiles) {
            $path = Join-Path $script:ConfigDir $file
            if (Test-Path $path) {
                Write-Success "$file"
            } else {
                Write-Warning "$file (not found)"
            }
        }

        Write-Section "Documentation"
        $docsDir = Join-Path $script:ConfigDir "docs"
        if (Test-Path $docsDir) {
            $docCount = (Get-ChildItem $docsDir -Filter "*.md").Count
            Write-Success "docs/ ($docCount files)"
        } else {
            Write-Warning "docs/ (not found)"
        }
    }

    Write-Host ""
}

function Test-Dependencies {
    Write-Section "Checking Dependencies"

    $allOk = $true

    # PowerShell 7+
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -ge 7) {
        Write-Success "PowerShell $psVersion"
    } else {
        Write-Error "PowerShell 7+ required (found $psVersion)"
        $allOk = $false
    }

    # uv
    try {
        $uvVersion = uv --version 2>$null
        Write-Success "uv $uvVersion"
    } catch {
        Write-Error "uv not found (required for ccproxy installation)"
        Write-Info "Install from: https://docs.astral.sh/uv/"
        $allOk = $false
    }

    # ccproxy
    try {
        $ccproxyVersion = ccproxy --version 2>$null
        Write-Success "ccproxy $ccproxyVersion"
    } catch {
        Write-Warning "ccproxy not installed"
        Write-Info "Will be installed: uv tool install claude-ccproxy --with 'litellm[proxy]'"
    }

    # Claude Code
    $claudePath = "$env:USERPROFILE\.local\bin\claude.exe"
    if (Test-Path $claudePath) {
        Write-Success "Claude Code CLI"
    } else {
        Write-Warning "Claude Code CLI not found at $claudePath"
    }

    Write-Host ""
    return $allOk
}

function Install-CCProxy {
    Write-Section "Installing CCProxy"

    try {
        Write-Info "Running: uv tool install claude-ccproxy --with 'litellm[proxy]'"
        uv tool install claude-ccproxy --with 'litellm[proxy]'
        Write-Success "CCProxy installed"
        return $true
    } catch {
        Write-Error "Failed to install ccproxy: $_"
        return $false
    }
}

function Copy-SystemFiles {
    param([bool]$IsUpdate = $false)

    Write-Section "$(if ($IsUpdate) { 'Updating' } else { 'Installing' }) System Files"

    # Create config directory
    if (-not (Test-Path $script:ConfigDir)) {
        New-Item -ItemType Directory -Path $script:ConfigDir -Force | Out-Null
        Write-Success "Created $script:ConfigDir"
    }

    # Create docs directory
    $docsDir = Join-Path $script:ConfigDir "docs"
    if (-not (Test-Path $docsDir)) {
        New-Item -ItemType Directory -Path $docsDir -Force | Out-Null
    }

    # Copy system files (always overwrite)
    foreach ($file in $script:SystemFiles) {
        $src = Join-Path $script:ScriptDir $file
        $dest = Join-Path $script:ConfigDir $file

        if (Test-Path $src) {
            Copy-Item $src $dest -Force
            Write-Success "$file"
        }
    }

    # Copy documentation files (always overwrite)
    foreach ($file in $script:DocFiles) {
        $src = Join-Path $script:ScriptDir $file
        $dest = Join-Path $script:ConfigDir $file

        if (Test-Path $src) {
            # Ensure parent directory exists
            $parent = Split-Path $dest -Parent
            if (-not (Test-Path $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }
            Copy-Item $src $dest -Force
            Write-Info "$file"
        }
    }

    # Save version
    $script:Version | Set-Content "$script:ConfigDir\.version" -NoNewline
}

function Copy-UserConfigTemplates {
    Write-Section "Setting Up User Config Files"

    Write-Host ""
    Write-Host "  These files store your personal configuration:"
    Write-Host "    - config.yaml    Your API keys (GLM, OpenAI, Gemini, etc.)"
    Write-Host "    - ccproxy.yaml   Routing rules and OAuth settings"
    Write-Host "    - .env           Environment variables"
    Write-Host ""
    Write-Host "  They will be created from templates. You'll need to add your API keys."
    Write-Host ""

    foreach ($template in $script:TemplateFiles) {
        $src = Join-Path $script:ScriptDir $template.Source
        $dest = Join-Path $script:ConfigDir $template.Target

        if (Test-Path $dest) {
            Write-Skip "$($template.Target) (already exists - preserved)"
        } elseif (Test-Path $src) {
            Copy-Item $src $dest
            Write-Success "$($template.Target) (created from template)"
        } else {
            Write-Warning "$($template.Target) (template not found: $($template.Source))"
        }
    }
}

function Update-PowerShellProfile {
    Write-Section "PowerShell Profile"

    $profilePath = $PROFILE
    $examplePath = Join-Path $script:ScriptDir "Microsoft.PowerShell_profile.example.ps1"

    if (-not (Test-Path $profilePath)) {
        # Create new profile
        $confirm = Read-Host "Create PowerShell profile with cclaude function? [Y/n]"
        if ($confirm -eq "" -or $confirm.ToLower().StartsWith("y")) {
            if (Test-Path $examplePath) {
                $content = Get-Content $examplePath -Raw
                New-Item -ItemType File -Path $profilePath -Force | Out-Null
                Set-Content $profilePath $content
                Write-Success "Created profile with cclaude function"
            }
        } else {
            Write-Skip "Profile creation skipped"
        }
    } else {
        # Check if cclaude exists
        $profileContent = Get-Content $profilePath -Raw
        if ($profileContent -like "*function cclaude*") {
            Write-Success "cclaude function already in profile"
            Write-Info "To update, see: Microsoft.PowerShell_profile.example.ps1"
        } else {
            Write-Warning "cclaude function not found in profile"
            Write-Info "Add manually from: Microsoft.PowerShell_profile.example.ps1"
        }
    }
}

function Show-NextSteps {
    param([bool]$IsUpdate = $false)

    Write-Header "$(if ($IsUpdate) { 'Update' } else { 'Setup' }) Complete!"

    if ($IsUpdate) {
        Write-Host "  System files have been updated."
        Write-Host "  Your config files were preserved:"
        Write-Host "    - ccproxy.yaml"
        Write-Host "    - config.yaml"
        Write-Host "    - .env"
    } else {
        Write-Host "  CCProxy has been installed."
        Write-Host ""
        Write-Host "  Next steps:"
        Write-Host "  1. Edit $script:ConfigDir\config.yaml"
        Write-Host "     - Add your API keys for providers you want to use"
        Write-Host ""
        Write-Host "  2. Edit $script:ConfigDir\ccproxy.yaml"
        Write-Host "     - Configure routing rules (optional)"
        Write-Host ""
        Write-Host "  3. Reload your PowerShell profile:"
        Write-Host "     . `$PROFILE"
        Write-Host ""
        Write-Host "  4. Start Claude Code with CCProxy:"
        Write-Host "     cclaude"
    }

    Write-Host ""
    Write-Host "  Documentation: $script:ConfigDir\docs\"
    Write-Host "  Watchdog log:  $script:ConfigDir\watchdog.log"
    Write-Host ""
}

# Main entry point
if ($Help) {
    Show-Help
    return
}

if ($Check) {
    Show-Status
    return
}

Write-Header "CCProxy PowerShell Setup v$script:Version"

# Check for existing installation
$existingInstall = Test-ExistingInstall

if ($existingInstall -and -not $Update -and -not $Force) {
    Write-Host "  Existing installation detected at: $script:ConfigDir"
    Write-Host ""
    Write-Host ($Colors.Cyan + "  Choose an option:" + $Colors.Reset)
    Write-Host ""
    Write-Host ($Colors.Green + "  [U] Update" + $Colors.Reset + " - Update system files only (RECOMMENDED)")
    Write-Host "      Updates: watchdog.ps1, documentation, scripts"
    Write-Host "      Preserves: Your API keys, routing rules, OAuth config"
    Write-Host ""
    Write-Host ($Colors.Yellow + "  [F] Fresh Install" + $Colors.Reset + " - Overwrite everything (START OVER)")
    Write-Host "      " + ($Colors.Red + "WARNING: This will DELETE your existing configuration!" + $Colors.Reset)
    Write-Host "      You will lose:"
    Write-Host "        - config.yaml    (your API keys for GLM, OpenAI, Gemini, etc.)"
    Write-Host "        - ccproxy.yaml   (your routing rules and OAuth settings)"
    Write-Host "        - .env           (your environment variables)"
    Write-Host ""
    Write-Host "  [C] Cancel - Exit without changes"
    Write-Host ""

    $choice = Read-Host "  Enter choice (U/F/C)"

    switch ($choice.ToLower()) {
        "u" { $Update = $true }
        "f" {
            Write-Host ""
            Write-Host ($Colors.Red + "  Are you sure? This will delete your API keys and routing config." + $Colors.Reset)
            $confirm = Read-Host "  Type 'YES' to confirm fresh install"
            if ($confirm -eq "YES") {
                $Force = $true
            } else {
                Write-Host "  Fresh install cancelled."
                return
            }
        }
        default {
            Write-Host "  Setup cancelled."
            return
        }
    }
}

# Check dependencies
$depsOk = Test-Dependencies
if (-not $depsOk -and -not $Force) {
    Write-Host "  Some dependencies are missing. Continue anyway? [y/N]"
    $confirm = Read-Host
    if (-not $confirm.ToLower().StartsWith("y")) {
        return
    }
}

# Install ccproxy if needed
try {
    ccproxy --version 2>$null | Out-Null
} catch {
    $confirm = Read-Host "Install ccproxy via uv? [Y/n]"
    if ($confirm -eq "" -or $confirm.ToLower().StartsWith("y")) {
        if (-not (Install-CCProxy)) {
            return
        }
    }
}

# Copy files
if ($Update) {
    # Update mode - only system files
    Copy-SystemFiles -IsUpdate $true
    Show-NextSteps -IsUpdate $true
} else {
    # Fresh install or force
    Copy-SystemFiles -IsUpdate $false
    Copy-UserConfigTemplates
    Update-PowerShellProfile
    Show-NextSteps -IsUpdate $false
}
