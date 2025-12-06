# ============================================================================
# CCProxy PowerShell Profile Configuration
# ============================================================================
# Copy this entire file content to your PowerShell profile:
# C:\Users\<YourUsername>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
#
# Quick setup:
# 1. Run: notepad $PROFILE
# 2. Paste this entire file
# 3. Save and close
# 4. Run: . $PROFILE
# ============================================================================

# Claude Code alias with auto-start CCProxy
function cclaude {
    # Set UTF-8 encoding for CCProxy (Windows compatibility fix for Bug #2)
    $env:PYTHONIOENCODING = 'utf-8'

    # Check if CCProxy is running
    $ccproxyStatus = ccproxy --config-dir "$env:USERPROFILE\.ccproxy" status 2>&1

    if ($ccproxyStatus -notlike '*running*') {
        Write-Host 'Starting CCProxy...' -ForegroundColor Yellow
        ccproxy --config-dir "$env:USERPROFILE\.ccproxy" start --detach 2>&1 | Out-Null
        Start-Sleep -Seconds 3
        Write-Host 'CCProxy started' -ForegroundColor Green
    }

    # Redirect Claude Code requests through CCProxy
    # This enables intelligent routing and OAuth forwarding
    $env:ANTHROPIC_BASE_URL = 'http://localhost:4000'

    # Start Claude Code CLI from .local\bin (proper installation)
    & "$env:USERPROFILE\.local\bin\claude.exe" @args
}

# ============================================================================
# Optional: PowerShell Quality of Life Improvements
# ============================================================================

# Fix paste issues in PowerShell
Set-PSReadLineOption -BellStyle None

if (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue) {
    try {
        # Disable prediction to prevent paste issues
        Set-PSReadLineOption -PredictionSource None
    } catch {
        # Silently continue if this fails
    }
}

# Allow Alt+Number keys to insert characters (useful for special characters)
Set-PSReadLineKeyHandler -Key Alt+0,Alt+1,Alt+2,Alt+3,Alt+4,Alt+5,Alt+6,Alt+7,Alt+8,Alt+9 -Function SelfInsert

# Remove Alt+. keybinding (can interfere with typing)
Remove-PSReadLineKeyHandler -Chord 'Alt+.'

# ============================================================================
# Usage
# ============================================================================
# After adding this to your profile, simply run:
#   cclaude
#
# This will:
# 1. Auto-start CCProxy if not running
# 2. Set ANTHROPIC_BASE_URL to route through proxy
# 3. Launch Claude Code CLI with OAuth support
# 4. Enable intelligent routing (high tokens, web search, thinking → GLM-4.6)
# ============================================================================
