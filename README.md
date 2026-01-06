# CCProxy for Windows PowerShell

> **Full Windows fork of [starbaser/ccproxy](https://github.com/starbaser/ccproxy)** with native Windows compatibility fixes.
> Route Claude Code requests through LiteLLM proxy to multiple AI providers with intelligent routing rules.

## What is this?

CCProxy intercepts Claude Code API requests and routes them to different LLM providers based on configurable rules. This lets you:

- **Use Claude Pro/Max subscription** (OAuth) for high-quality tasks
- **Route heavy workloads** to unlimited providers (GLM-4.6: $6/month)
- **Switch between providers** based on token count, tools used, or model requested
- **Configure different models per agent** (programming → GLM, design → Gemini, etc.)
- **Save costs** by routing appropriately instead of hitting Claude Max limits

## Features

### All Original CCProxy Features ✅
- OAuth token forwarding (Claude Pro & Max subscription)
- Model routing rules (ThinkingRule, TokenCountRule, MatchToolRule, MatchModelRule)
- Multi-provider support via LiteLLM
- Request/response logging with header capture
- Passthrough mode for unmatched requests

### Windows PowerShell Enhancements ✨
- **Full source code fork** - Includes all upstream code with Windows patches
- **Cross-platform process handling** - Fixed `os.kill()` crashes on Windows
- **PowerShell-native OAuth extraction** (no `jq` dependency)
- **Auto-start CCProxy** via PowerShell profile function
- **Watchdog auto-restart** handles Windows asyncio crash bug (CPython #93821)
- **Multi-provider templates** (OpenAI, Gemini, Vertex AI, Azure, Perplexity, Mistral)
- **Agent-specific routing** documentation and examples
- **Setup script** with safe updates (preserves user config)

## Quick Start

### Prerequisites

- Windows 10/11 with PowerShell 7+
- [Claude Code CLI](https://claude.ai/download) installed
- [uv](https://docs.astral.sh/uv/) package manager
- Claude Pro or Max subscription (for OAuth) or API keys for other providers

### Option A: Automated Setup (Recommended)

```powershell
# Clone this repo
git clone https://github.com/gmax111/ccproxy-powershell.git
cd ccproxy-powershell

# Run setup script from windows directory
.\windows\setup.ps1
```

The setup script will:
1. Check dependencies (PowerShell 7+, uv, Claude Code CLI)
2. Install ccproxy from this local repo (with Windows fixes)
3. Create config directory at `~\.ccproxy`
4. Copy template files (won't overwrite existing configs)
5. Optionally set up your PowerShell profile with `cclaude` function

### Option B: Manual Setup

### 1. Install CCProxy (from this repo)

```powershell
# Clone the repo
git clone https://github.com/gmax111/ccproxy-powershell.git
cd ccproxy-powershell

# Install from local source (includes Windows fixes)
uv tool install . --force

# Verify installation
ccproxy status
```

### 2. Create Configuration Directory

```powershell
# Create config directory
New-Item -ItemType Directory -Path "$env:USERPROFILE\.ccproxy" -Force

# Copy template configs
Copy-Item ccproxy.yaml.example "$env:USERPROFILE\.ccproxy\ccproxy.yaml"
Copy-Item config.yaml.example "$env:USERPROFILE\.ccproxy\config.yaml"
Copy-Item windows\watchdog.ps1 "$env:USERPROFILE\.ccproxy\watchdog.ps1"
```

### 3. Configure OAuth (Claude Pro/Max Users)

Edit `~/.ccproxy/ccproxy.yaml` and update the OAuth path:

```yaml
oat_sources:
  anthropic: "powershell.exe -Command \"(Get-Content '$env:USERPROFILE\\.claude\\.credentials.json' | ConvertFrom-Json).claudeAiOauth.accessToken\""
```

### 4. Set Up PowerShell Profile

```powershell
# Open your PowerShell profile
notepad $PROFILE

# Add the cclaude function (see windows/Microsoft.PowerShell_profile.example.ps1)
```

Paste this function:

```powershell
function cclaude {
    # Set UTF-8 encoding for CCProxy
    $env:PYTHONIOENCODING = 'utf-8'

    # Check if CCProxy is running
    $ccproxyStatus = ccproxy --config-dir "$env:USERPROFILE\.ccproxy" status 2>&1

    if ($ccproxyStatus -notlike '*running*') {
        Write-Host 'Starting CCProxy...' -ForegroundColor Yellow
        ccproxy --config-dir "$env:USERPROFILE\.ccproxy" start --detach 2>&1 | Out-Null
        Start-Sleep -Seconds 3
        Write-Host 'CCProxy started' -ForegroundColor Green
    }

    # Redirect Claude Code through CCProxy
    $env:ANTHROPIC_BASE_URL = 'http://localhost:4000'

    # Start Claude Code
    & "$env:USERPROFILE\.local\bin\claude.exe" @args
}
```

### 5. Start Using Claude Code with CCProxy

```powershell
# Reload profile
. $PROFILE

# Launch Claude Code (will auto-start CCProxy)
cclaude

# In Claude Code, test routing
/model glm-4.6
> who are you?

# Switch back to Claude
/model sonnet
> explain quantum computing
```

## Documentation

- **[Routing Rules](docs/ROUTING-RULES.md)** - All 4 routing rules explained
- **[Provider Setup](docs/PROVIDERS.md)** - OpenAI, Gemini, Azure, etc.
- **[Agent Routing](docs/AGENT-ROUTING.md)** - Configure models per agent
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues & fixes

## Supported Providers

| Provider | Authentication | Notes |
|----------|---------------|-------|
| **Anthropic Claude** | OAuth (Claude Pro/Max) | via `.credentials.json` |
| **Z.ai GLM** | API Key | $6/month unlimited coding plan |
| **OpenRouter** | API Key | DeepSeek, Llama, etc. |
| **OpenAI** | API Key | GPT-4o, o1-preview, etc. |
| **Google Gemini** | API Key | Gemini 2.0 Flash, 1.5 Pro |
| **Google Vertex AI** | Service Account | Enterprise Gemini |
| **Azure OpenAI** | API Key | Enterprise GPT models |
| **Perplexity** | API Key | Web search models |
| **Mistral AI** | API Key | European alternative |
| **Ollama** | Local | Free local models |

See [docs/PROVIDERS.md](docs/PROVIDERS.md) for setup instructions for each provider.

## Routing Rules

### ThinkingRule
Routes requests with extended thinking enabled to cheaper/unlimited models.

```yaml
- name: extended_thinking
  rule: ccproxy.rules.ThinkingRule
```

### TokenCountRule
Routes high-token requests (>60k tokens) to high-capacity models.

```yaml
- name: high_token_count
  rule: ccproxy.rules.TokenCountRule
  params:
    threshold: 60000
```

### MatchToolRule
Routes requests using specific tools (WebSearch, etc.) to appropriate models.

```yaml
- name: web_search
  rule: ccproxy.rules.MatchToolRule
  params:
    tool_name: WebSearch
```

### MatchModelRule
Routes based on model name pattern (regex matching).

```yaml
- name: think-mode
  rule: ccproxy.rules.MatchModelRule
  params:
    model_name: ".*think.*"
```

See [docs/ROUTING-RULES.md](docs/ROUTING-RULES.md) for detailed explanations and use cases.

## Agent-Specific Routing

Configure different models for different agents by adding model to agent frontmatter:

```markdown
---
name: engineer
model: glm-4.6
---

# Engineer Agent
```

```markdown
---
name: ux-designer
model: gemini-2.0-flash
---

# UX Designer Agent
```

See [docs/AGENT-ROUTING.md](docs/AGENT-ROUTING.md) for complete guide.

## Cost Optimization Example

**Without CCProxy:**
- Claude Max: $100/month with session limits
- Exceeding limits → expensive API usage charges

**With CCProxy + GLM-4.6:**
- Claude Max: $100/month for high-quality interactive work
- GLM-4.6: $6/month unlimited for heavy token tasks
- **Total: $106/month** with effectively unlimited capacity

Route think mode, long context, and background tasks to GLM → stay within Claude Max limits.

## Windows Compatibility Fixes

This fork includes **code-level fixes** for Windows-specific issues:

1. **`os.kill()` crash** - Replaced with cross-platform `_process_exists()` and `_terminate_process()` helpers using ctypes/taskkill
2. **Unicode encoding** - Set `PYTHONIOENCODING='utf-8'` in cclaude function
3. **Asyncio crash (CPython #93821)** - Watchdog auto-restart as safety net
4. **Health check on startup** - Upstream Dec 7 fix included

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for details.

## Project Structure

```
ccproxy-powershell/
├── src/ccproxy/                        # Python source (with Windows patches)
│   ├── cli.py                          # CLI with cross-platform process handling
│   ├── config.py                       # Configuration management
│   ├── handler.py                      # Request handler
│   ├── hooks.py                        # LiteLLM hooks
│   ├── router.py                       # Model router
│   └── rules.py                        # Routing rules
├── windows/                            # Windows-specific files
│   ├── setup.ps1                       # Setup script
│   ├── watchdog.ps1                    # Auto-restart on crash
│   └── Microsoft.PowerShell_profile.example.ps1
├── docs/                               # Documentation
│   ├── ROUTING-RULES.md
│   ├── PROVIDERS.md
│   ├── AGENT-ROUTING.md
│   └── TROUBLESHOOTING.md
├── pyproject.toml                      # Package configuration
├── ccproxy.yaml.example                # Routing config template
├── config.yaml.example                 # Provider config template
└── .env.example                        # API key placeholders
```

## Differences from Original Repo

### This is a Full Fork
Unlike the original Windows companion repo, this fork **includes the complete source code** with Windows compatibility patches applied directly to the Python code.

### What's Fixed in Code ✅
- **`os.kill()` crashes** - Cross-platform process handling via ctypes (Windows) or signals (Unix)
- **Health check startup** - Dec 7 upstream fix included

### What's Enhanced ✨
- **Windows PowerShell compatibility** - All commands work natively
- **Auto-start functionality** - PowerShell profile handles startup
- **Multi-provider templates** - Ready-to-use examples for 8+ providers
- **Agent routing documentation** - Model-per-agent configuration guide
- **Watchdog safety net** - Auto-restart on crash (for CPython #93821)

## Contributing

Found a bug or have an enhancement? Open an issue or PR!

## License

AGPL-3.0-or-later (same as original [starbaser/ccproxy](https://github.com/starbaser/ccproxy))

## Credits

- **Original CCProxy**: [starbaser/ccproxy](https://github.com/starbaser/ccproxy)
- **LiteLLM**: [BerriAI/litellm](https://github.com/BerriAI/litellm)
- **Windows Fork**: This repo

## Support

- **Issues**: Open a GitHub issue
- **Original CCProxy docs**: https://github.com/starbaser/ccproxy
- **LiteLLM docs**: https://docs.litellm.ai/

---

**Quick Links:**
- [Provider Setup](docs/PROVIDERS.md)
- [Routing Rules](docs/ROUTING-RULES.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
