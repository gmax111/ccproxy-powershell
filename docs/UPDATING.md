# Updating CCProxy PowerShell

This guide explains how to update your CCProxy installation when new versions are released.

## Safe Update Process

The setup script uses a **safe update system** that:
- **Updates** system files (watchdog, documentation, scripts)
- **Preserves** your user configuration (API keys, routing rules, OAuth config)

### User Config Files (Never Overwritten)

These files contain your personal settings and are **never** modified during updates:

| File | Contents |
|------|----------|
| `ccproxy.yaml` | OAuth config, routing rules, hooks |
| `config.yaml` | API keys, model deployments |
| `.env` | Environment variables |

### System Files (Updated Automatically)

These files are safe to update and will be overwritten:

| File | Purpose |
|------|---------|
| `watchdog.ps1` | Auto-restart on crash |
| `show-models.ps1` | List available models |
| `docs/*` | Documentation |
| `README.md` | Main readme |

## How to Update

### Method 1: Using Setup Script (Recommended)

```powershell
# Navigate to your cloned repo
cd path\to\ccproxy-powershell

# Pull latest changes
git pull

# Run setup in update mode
.\setup.ps1 -Update
```

This will:
1. Update system files (watchdog, docs)
2. Skip your config files (ccproxy.yaml, config.yaml, .env)
3. Show what changed

### Method 2: Check Status First

```powershell
# See current installation status
.\setup.ps1 -Check

# Output shows:
# - Installed version
# - Script version (what you'll update to)
# - Status of all files
```

### Method 3: Manual Update

If you prefer manual control:

```powershell
# Update only the watchdog
Copy-Item watchdog.ps1 "$env:USERPROFILE\.ccproxy\watchdog.ps1" -Force

# Update documentation
Copy-Item -Recurse docs "$env:USERPROFILE\.ccproxy\" -Force

# Update profile example (review, don't copy blindly)
# Compare: Microsoft.PowerShell_profile.example.ps1 with your $PROFILE
```

## Checking for Updates

### Using Git

```powershell
cd path\to\ccproxy-powershell
git fetch
git log HEAD..origin/main --oneline
```

### Version File

After running setup, check your installed version:

```powershell
Get-Content "$env:USERPROFILE\.ccproxy\.version"
```

## Breaking Changes

When a new version has breaking changes, the README and CHANGELOG will note:

1. **Config Format Changes** - You may need to update ccproxy.yaml structure
2. **New Required Fields** - Compare your config with the new template
3. **Removed Features** - Check if you're using deprecated features

### Handling Breaking Changes

1. **Backup your config first:**
   ```powershell
   Copy-Item "$env:USERPROFILE\.ccproxy\ccproxy.yaml" "$env:USERPROFILE\.ccproxy\ccproxy.yaml.backup"
   ```

2. **Review the new template:**
   ```powershell
   # See what changed
   diff "$env:USERPROFILE\.ccproxy\ccproxy.yaml" .\ccproxy.yaml
   ```

3. **Merge manually if needed:**
   - Copy new structure from template
   - Add your API keys and custom settings back

## Rollback

If something breaks after an update:

```powershell
# Restore from backup (if you made one)
Copy-Item "$env:USERPROFILE\.ccproxy\ccproxy.yaml.backup" "$env:USERPROFILE\.ccproxy\ccproxy.yaml"

# Or checkout previous version
cd path\to\ccproxy-powershell
git checkout v1.0.0  # or whatever version worked
.\setup.ps1 -Update
```

## Update FAQ

### Q: Will updating overwrite my API keys?

**No.** Your `config.yaml` file is classified as a user config file and is never touched during updates.

### Q: Will updating overwrite my routing rules?

**No.** Your `ccproxy.yaml` file is preserved. Only system files like `watchdog.ps1` are updated.

### Q: What if I modified watchdog.ps1?

Your changes will be overwritten. If you have custom watchdog logic:
1. Save your changes elsewhere
2. Run the update
3. Re-apply your customizations
4. Consider contributing your improvements back to the repo

### Q: How do I know if my config needs changes?

Compare your config with the new template:

```powershell
# See differences
diff "$env:USERPROFILE\.ccproxy\ccproxy.yaml" .\ccproxy.yaml
diff "$env:USERPROFILE\.ccproxy\config.yaml" .\config.yaml
```

### Q: Can I force a fresh install?

Yes, but be careful:

```powershell
# This will overwrite EVERYTHING including your configs
.\setup.ps1 -Force

# You'll need to re-enter your API keys and settings
```

## Changelog

See [CHANGELOG.md](../CHANGELOG.md) for version history and breaking changes.
