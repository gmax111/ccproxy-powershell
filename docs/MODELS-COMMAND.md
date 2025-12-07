# `/models` Command and CCProxy

## The Issue

When you type `/models` in Claude Code and press Enter, you see a dropdown list of available models. Currently, this list **only shows Anthropic's models** (Opus, Sonnet, Haiku) even though CCProxy is routing to multiple providers.

## Why This Happens

The `/models` dropdown is **hardcoded in Claude Code** and doesn't query CCProxy's `/v1/models` endpoint. This is a Claude Code limitation, not a CCProxy limitation.

**Proof**: CCProxy's LiteLLM proxy IS exposing all your models correctly:

```powershell
# Query the proxy endpoint
Invoke-RestMethod -Uri 'http://localhost:4000/v1/models' -Method Get

# Returns ALL configured models:
# - claude-sonnet-4-5-20250929
# - claude-opus-4-5-20251101
# - claude-haiku-4-5-20251001
# - glm-4.6
# - glm-4.5-air
# - deepseek-chat
# - llama3.1
# - (routing rule models: default, high_token_count, web_search, extended_thinking)
```

Claude Code just doesn't use this endpoint for the `/models` command.

## Workarounds

### Workaround 1: Use `/model [model-name]` Directly

You don't need to select from the dropdown. Just type the model name:

```
/model glm-4.6
/model deepseek-chat
/model llama3.1
```

**This works immediately** - no configuration needed.

### Workaround 2: Quick Reference Script

Run this script anytime to see all available models:

```powershell
.\.ccproxy\show-models.ps1
```

Output:
```
========================================
CCProxy Available Models
========================================

Usage:
  /model [model-name]

ANTHROPIC (Claude Max OAuth)
  claude-sonnet-4-5-20250929    - Claude Sonnet 4.5 (default)
  claude-opus-4-5-20251101      - Claude Opus 4.5 (highest quality)
  claude-haiku-4-5-20251001     - Claude Haiku 4.5 (fast)

Z.AI GLM (Unlimited $6/month)
  glm-4.6                       - GLM-4.6 (unlimited tokens)
  glm-4.5-air                   - GLM-4.5 Air (lighter)

OPENROUTER (DeepSeek)
  deepseek-chat                 - DeepSeek Chat (coding)

OLLAMA (Local - Free)
  llama3.1                      - Llama 3.1 8B (local, private)
```

### Workaround 3: Set Default Model in settings.json

Set your most-used model as the default:

```json
{
  "model": "glm-4.6"
}
```

Now Claude Code will use `glm-4.6` by default without needing to specify it.

### Workaround 4: Print Models to Terminal

Add this function to your PowerShell profile for quick access:

```powershell
# Add to: $PROFILE (Microsoft.PowerShell_profile.ps1)
function Get-CCProxyModels {
    Write-Host ""
    Write-Host "Available CCProxy Models:" -ForegroundColor Cyan
    Write-Host "  Anthropic:  opus, sonnet, haiku" -ForegroundColor Gray
    Write-Host "  GLM:        glm-4.6, glm-4.5-air" -ForegroundColor Gray
    Write-Host "  OpenRouter: deepseek-chat" -ForegroundColor Gray
    Write-Host "  Ollama:     llama3.1" -ForegroundColor Gray
    Write-Host ""
}

# Alias
Set-Alias -Name ccmodels -Value Get-CCProxyModels
```

Then just run:
```powershell
ccmodels
```

## Long-Term Solution

This would require a change to Claude Code itself. Potential options:

1. **Feature Request**: Ask Anthropic to query the proxy's `/v1/models` endpoint
2. **Custom Dropdown**: Add `modelList` setting to settings.json (would need Anthropic to implement)
3. **MCP Server**: Create an MCP server that provides model discovery (complex)

Until then, use Workaround 1 (just type the model name) - it's the simplest solution.

## Related Files

- `~/.ccproxy/config.yaml` - Your model definitions
- `~/.ccproxy/show-models.ps1` - Quick reference script
- `~/.claude/settings.json` - Default model setting

## Quick Reference Table

| Model Name | Provider | Cost | Use Case |
|------------|----------|------|----------|
| `claude-sonnet-4-5-20250929` | Anthropic | Claude Max | Default, balanced |
| `claude-opus-4-5-20251101` | Anthropic | Claude Max | Highest quality |
| `claude-haiku-4-5-20251001` | Anthropic | Claude Max | Fast, simple tasks |
| `glm-4.6` | Z.ai | $6/month unlimited | Heavy token work |
| `glm-4.5-air` | Z.ai | $6/month unlimited | Lighter variant |
| `deepseek-chat` | OpenRouter | Per-token | Coding tasks |
| `llama3.1` | Ollama | Free (local) | Private, offline |

---

**Bottom line**: Just use `/model glm-4.6` instead of picking from the dropdown. It works perfectly, and CCProxy routes correctly to all configured models.
