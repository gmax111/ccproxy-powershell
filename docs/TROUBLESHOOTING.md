# Troubleshooting Guide

Solutions to common issues when running CCProxy on Windows PowerShell.

## Table of Contents

- [Windows-Specific Issues](#windows-specific-issues)
- [Installation Issues](#installation-issues)
- [Startup Issues](#startup-issues)
- [Routing Issues](#routing-issues)
- [Authentication Issues](#authentication-issues)
- [Provider Issues](#provider-issues)
- [Performance Issues](#performance-issues)
- [Debugging](#debugging)

---

## Windows-Specific Issues

### Bug #1: litellm executable not found

**Symptom**:
```
Error: 'litellm' is not recognized as an internal or external command
```

**Cause**: CCProxy checks for `litellm` but Windows needs `litellm.exe`

**Fix**: Create a copy without the extension

```powershell
# Find litellm.exe location
$litellmPath = Get-Command litellm | Select-Object -ExpandProperty Source

# Create copy without .exe
$litellmDir = Split-Path $litellmPath
Copy-Item "$litellmDir\litellm.exe" "$litellmDir\litellm"
```

**Typical location**:
```
C:\Users\<username>\AppData\Roaming\uv\tools\claude-ccproxy\Scripts\litellm
```

---

### Bug #2: Unicode encoding error

**Symptom**:
```
UnicodeEncodeError: 'charmap' codec can't encode characters in position 0-2: character maps to <undefined>
```

**Cause**: LiteLLM banner uses Unicode characters that Windows console (cp1252) can't display

**Fix**: Set UTF-8 encoding before starting CCProxy

```powershell
$env:PYTHONIOENCODING = 'utf-8'
ccproxy --config-dir "$env:USERPROFILE\.ccproxy" start --detach
```

**Permanent fix**: Add to PowerShell profile

```powershell
# In your $PROFILE
function cclaude {
    $env:PYTHONIOENCODING = 'utf-8'  # ← Fix applied here
    # ... rest of function
}
```

---

### Bug #3: Double /v1/ in API path

**Symptom**:
```
404 Not Found: /v1/v1/messages
```

**Cause**: API base URL had `/v1` suffix, LiteLLM appended `/v1/messages`

**Fix**: Remove `/v1` from `api_base` in config.yaml

```yaml
# ❌ WRONG
model_list:
  - model_name: glm-4.6
    litellm_params:
      api_base: https://open.bigmodel.cn/api/anthropic/v1

# ✅ CORRECT
model_list:
  - model_name: glm-4.6
    litellm_params:
      api_base: https://open.bigmodel.cn/api/anthropic
```

---

### Bug #4: os.kill() compatibility error

**Symptom**:
```
SystemError: <built-in function kill> returned a result with an exception set
```

**Cause**: CCProxy uses `os.kill(pid, 0)` to check if process exists - Unix-specific signal not supported on Windows

**Workaround**: Run ccproxy from **native PowerShell** (not WSL → PowerShell)

```powershell
# ✅ Run from native PowerShell
cclaude

# ❌ Don't run from WSL
wsl.exe -e bash -c "ccproxy start --detach"  # Will fail
```

**Note**: The `cclaude` PowerShell function should work correctly when run from native PowerShell.

---

## Installation Issues

### CCProxy not found after installation

**Symptom**:
```powershell
ccproxy
# 'ccproxy' is not recognized
```

**Cause**: `uv` tools directory not in PATH

**Fix**: Add to PATH

```powershell
# Check if directory exists
Test-Path "$env:USERPROFILE\AppData\Roaming\uv\tools\claude-ccproxy\Scripts"

# Add to PATH (current session)
$env:PATH += ";$env:USERPROFILE\AppData\Roaming\uv\tools\claude-ccproxy\Scripts"

# Add to PATH (permanent)
[Environment]::SetEnvironmentVariable(
    "PATH",
    [Environment]::GetEnvironmentVariable("PATH", "User") + ";$env:USERPROFILE\AppData\Roaming\uv\tools\claude-ccproxy\Scripts",
    "User"
)
```

**Verify**:
```powershell
ccproxy --version
```

---

### Installation fails with dependency errors

**Symptom**:
```
ERROR: Could not find a version that satisfies the requirement litellm[proxy]
```

**Fix**: Ensure you have the correct install command

```powershell
# ✅ CORRECT
uv tool install claude-ccproxy --with 'litellm[proxy]'

# ❌ WRONG - missing quotes around litellm[proxy]
uv tool install claude-ccproxy --with litellm[proxy]
```

**Alternative**: Install in two steps

```powershell
uv tool install claude-ccproxy
uv tool install litellm[proxy]
```

---

## Startup Issues

### CCProxy won't start - port 4000 in use

**Symptom**:
```
Error: Address already in use: 127.0.0.1:4000
```

**Cause**: Another process is using port 4000

**Fix 1**: Find and kill the process

```powershell
# Find process using port 4000
Get-NetTCPConnection -LocalPort 4000 | Select-Object OwningProcess

# Kill the process
Stop-Process -Id <PID>
```

**Fix 2**: Use a different port

Edit `ccproxy.yaml`:
```yaml
litellm:
  port: 4001  # Change port
```

Update PowerShell profile:
```powershell
$env:ANTHROPIC_BASE_URL = 'http://localhost:4001'
```

---

### CCProxy starts but immediately exits

**Symptom**: CCProxy starts then stops without error

**Cause**: Config file syntax error

**Fix**: Validate YAML syntax

```powershell
# Check for syntax errors
Get-Content "$env:USERPROFILE\.ccproxy\ccproxy.yaml"

# Common issues:
# - Missing quotes around strings with special chars
# - Incorrect indentation (use spaces, not tabs)
# - Missing colon after key names
```

**Validate online**: https://www.yamllint.com/

---

### Connection refused when accessing http://localhost:4000

**Symptom**:
```
Connection refused: localhost:4000
```

**Cause**: CCProxy not running

**Check status**:
```powershell
ccproxy --config-dir "$env:USERPROFILE\.ccproxy" status
```

**Restart**:
```powershell
ccproxy --config-dir "$env:USERPROFILE\.ccproxy" stop
ccproxy --config-dir "$env:USERPROFILE\.ccproxy" start --detach
```

**Verify port is listening**:
```powershell
Test-NetConnection -ComputerName localhost -Port 4000
```

---

## Routing Issues

### All requests route to wrong model

**Symptom**: Every request goes to GLM instead of Claude

**Cause**: ThinkingRule matches ALL requests

**Fix**: Disable ThinkingRule in ccproxy.yaml

```yaml
rules:
  # - name: extended_thinking  # Comment out
  #   rule: ccproxy.rules.ThinkingRule

  - name: high_token_count      # Keep other rules
    rule: ccproxy.rules.TokenCountRule
    params:
      threshold: 60000
```

**Why this happens**: Claude Code sends `thinking: {enabled: true}` in every request, even when not using extended thinking mode.

---

### Rule not matching when it should

**Symptom**: Request should match rule but routes to default model

**Debug**: Enable debug logging

```yaml
ccproxy:
  debug: true

litellm:
  debug: true
  detailed_debug: true
```

**Check logs**:
```powershell
Get-Content "$env:USERPROFILE\.ccproxy\litellm.log" -Wait -Tail 30
```

Look for:
```
DEBUG - Evaluating rule: high_token_count
DEBUG - Token count: 45000, threshold: 60000
DEBUG - Rule did not match
```

**Common causes**:
1. Token count below threshold
2. Tool name spelling mismatch (case-sensitive)
3. Regex pattern doesn't match model name
4. Earlier rule matched first

---

### Model alias not found

**Symptom**:
```
Error: Model not found: high_token_count
```

**Cause**: Routing alias not defined in config.yaml

**Fix**: Add model definition with matching name

```yaml
# ccproxy.yaml rule name
rules:
  - name: high_token_count

# config.yaml model name must match exactly
model_list:
  - model_name: high_token_count  # Must match rule name
    litellm_params:
      model: anthropic/glm-4.6
      api_key: os.environ/GLM_API_KEY
      api_base: https://open.bigmodel.cn/api/anthropic
```

---

### TypeError: 'NoneType' object is not iterable

**Symptom**:
```
TypeError: 'NoneType' object is not iterable
```

**Cause**: `rules:` key has no value

```yaml
# ❌ WRONG - causes error
ccproxy:
  rules:

# ✅ CORRECT - empty list
ccproxy:
  rules: []

# ✅ CORRECT - with rules
ccproxy:
  rules:
    - name: high_token_count
      rule: ccproxy.rules.TokenCountRule
```

---

## Authentication Issues

### 401 Unauthorized with Anthropic

**Symptom**:
```
401 Unauthorized: Invalid API key
```

**Cause 1**: OAuth token not being forwarded

**Fix**: Check ccproxy.yaml hooks

```yaml
hooks:
  - ccproxy.hooks.rule_evaluator
  - ccproxy.hooks.model_router
  - ccproxy.hooks.forward_oauth  # ← Must be present
```

**Cause 2**: OAuth token extraction failing

**Fix**: Test token extraction manually

```powershell
# Test the command from oat_sources
powershell.exe -Command "(Get-Content '$env:USERPROFILE\.claude\.credentials.json' | ConvertFrom-Json).claudeAiOauth.accessToken"
```

Should output a long token starting with `eyJ...`

**Cause 3**: Credentials file not found

**Fix**: Verify file exists

```powershell
Test-Path "$env:USERPROFILE\.claude\.credentials.json"
```

If missing, login to Claude Code CLI first:
```powershell
claude auth login
```

---

### API key not found for provider

**Symptom**:
```
Error: API key not found for model glm-4.6
```

**Cause**: Environment variable not set

**Fix**: Set environment variable

```powershell
# Check if set
$env:GLM_API_KEY

# Set in current session
$env:GLM_API_KEY = "your-api-key.xxxxxxxx"

# Add to PowerShell profile for persistence
notepad $PROFILE
# Add line: $env:GLM_API_KEY = "your-api-key"
```

**Restart CCProxy** after setting variables:
```powershell
ccproxy --config-dir "$env:USERPROFILE\.ccproxy" stop
ccproxy --config-dir "$env:USERPROFILE\.ccproxy" start --detach
```

---

## Provider Issues

### GLM API returns 404

**Symptom**:
```
404 Not Found
```

**Cause**: Incorrect API base URL or double `/v1/`

**Fix**: Verify config.yaml

```yaml
model_list:
  - model_name: glm-4.6
    litellm_params:
      model: anthropic/glm-4.6  # Must have anthropic/ prefix
      api_key: os.environ/GLM_API_KEY
      api_base: https://open.bigmodel.cn/api/anthropic  # No /v1 suffix
```

---

### Provider returns "LLM Provider NOT provided"

**Symptom**:
```
litellm.BadRequestError: LLM Provider NOT provided. You passed model=glm-4.6
```

**Cause**: Missing provider prefix in model name

```yaml
# ❌ WRONG - no provider prefix
litellm_params:
  model: glm-4.6

# ✅ CORRECT - with provider prefix
litellm_params:
  model: anthropic/glm-4.6
```

---

### Gemini returns "API key not valid"

**Symptom**:
```
400 Bad Request: API key not valid
```

**Cause**: Invalid or expired API key

**Fix**: Generate new key

1. Go to https://aistudio.google.com/app/apikey
2. Create new API key
3. Update environment variable

```powershell
$env:GEMINI_API_KEY = "AIzaSy_NEW_KEY_HERE"
```

---

## Performance Issues

### Slow response times

**Symptom**: Requests take much longer than expected

**Cause 1**: Provider is slow (not CCProxy)

**Fix**: Test provider directly

```powershell
# Test Anthropic API directly
curl -X POST https://api.anthropic.com/v1/messages `
  -H "x-api-key: $env:ANTHROPIC_API_KEY" `
  -H "anthropic-version: 2023-06-01" `
  -H "content-type: application/json" `
  -d '{
    "model": "claude-sonnet-4-5-20250929",
    "max_tokens": 100,
    "messages": [{"role": "user", "content": "Hi"}]
  }'
```

**Cause 2**: Debug logging overhead

**Fix**: Disable detailed debug in production

```yaml
litellm:
  debug: false
  detailed_debug: false
```

---

### High memory usage

**Symptom**: CCProxy consuming excessive RAM

**Cause**: Multiple LiteLLM workers

**Fix**: Reduce worker count in ccproxy.yaml

```yaml
litellm:
  num_workers: 2  # Reduce from 4
```

---

## Debugging

### Enable debug logging

```yaml
# ccproxy.yaml
ccproxy:
  debug: true

litellm:
  debug: true
  detailed_debug: true
  log_file: C:\Users\<username>\.ccproxy\litellm.log
```

Restart CCProxy to apply changes.

---

### View logs in real-time

```powershell
# Watch logs as they're written
Get-Content "$env:USERPROFILE\.ccproxy\litellm.log" -Wait -Tail 30
```

---

### Test CCProxy without Claude Code

```powershell
# Direct API call to CCProxy
$headers = @{
    'Content-Type' = 'application/json'
    'anthropic-version' = '2023-06-01'
}

$body = @{
    model = 'glm-4.6'
    messages = @(
        @{
            role = 'user'
            content = 'Hello'
        }
    )
    max_tokens = 100
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri 'http://localhost:4000/v1/messages' -Method Post -Headers $headers -Body $body
```

---

### Check config file syntax

```powershell
# Read config and check for obvious errors
Get-Content "$env:USERPROFILE\.ccproxy\ccproxy.yaml"
Get-Content "$env:USERPROFILE\.ccproxy\config.yaml"

# Validate YAML online
# https://www.yamllint.com/
```

---

### Verify environment variables

```powershell
# List all relevant environment variables
Get-ChildItem env: | Where-Object { $_.Name -like "*API*" -or $_.Name -like "*KEY*" }

# Check specific variables
$env:ANTHROPIC_BASE_URL
$env:GLM_API_KEY
$env:OPENROUTER_API_KEY
$env:PYTHONIOENCODING
```

---

### Reset to clean state

```powershell
# Stop CCProxy
ccproxy --config-dir "$env:USERPROFILE\.ccproxy" stop

# Backup current config
Copy-Item "$env:USERPROFILE\.ccproxy" "$env:USERPROFILE\.ccproxy.backup" -Recurse

# Remove lock files
Remove-Item "$env:USERPROFILE\.ccproxy\litellm.pid" -ErrorAction SilentlyContinue

# Start fresh
ccproxy --config-dir "$env:USERPROFILE\.ccproxy" start --detach

# Watch logs
Get-Content "$env:USERPROFILE\.ccproxy\litellm.log" -Wait -Tail 30
```

---

## Common Error Messages

### "Cannot import name 'OpenAI' from 'litellm'"

**Fix**: Reinstall with correct dependencies

```powershell
uv tool uninstall claude-ccproxy
uv tool install claude-ccproxy --with 'litellm[proxy]'
```

---

### "YAML error: mapping values are not allowed here"

**Cause**: YAML syntax error (usually indentation)

**Fix**: Check indentation - use spaces, not tabs

```yaml
# ❌ WRONG - tabs or wrong indentation
ccproxy:
debug: true

# ✅ CORRECT - 2 spaces
ccproxy:
  debug: true
```

---

### "ModuleNotFoundError: No module named 'ccproxy'"

**Cause**: CCProxy not installed correctly

**Fix**: Reinstall

```powershell
uv tool uninstall claude-ccproxy
uv tool install claude-ccproxy --with 'litellm[proxy]'

# Verify installation
ccproxy --version
```

---

## Getting Help

### Check logs first

```powershell
Get-Content "$env:USERPROFILE\.ccproxy\litellm.log" -Tail 100
```

### Collect diagnostic info

```powershell
# CCProxy version
ccproxy --version

# Config files
Get-Content "$env:USERPROFILE\.ccproxy\ccproxy.yaml"
Get-Content "$env:USERPROFILE\.ccproxy\config.yaml"

# Environment
$env:ANTHROPIC_BASE_URL
$PSVersionTable
```

### Test individual components

1. **Test CCProxy startup**: `ccproxy --config-dir "$env:USERPROFILE\.ccproxy" status`
2. **Test port access**: `Test-NetConnection -ComputerName localhost -Port 4000`
3. **Test API call**: See "Test CCProxy without Claude Code" above
4. **Test OAuth extraction**: See "401 Unauthorized" section above

---

## Further Reading

- [CONFIGURATION.md](CONFIGURATION.md) - Full config file reference
- [ROUTING-RULES.md](ROUTING-RULES.md) - Routing rule details
- [PROVIDERS.md](PROVIDERS.md) - Provider-specific setup
- [AGENT-ROUTING.md](AGENT-ROUTING.md) - Agent configuration

---

## Still Having Issues?

If none of these solutions work:

1. Check logs: `$env:USERPROFILE\.ccproxy\litellm.log`
2. Enable debug logging in both config files
3. Test components individually (see above)
4. Try with minimal config (disable all routing rules)
5. Open GitHub issue with:
   - CCProxy version
   - Config files (redact API keys!)
   - Full error message
   - Log output
