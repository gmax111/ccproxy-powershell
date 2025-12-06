# Agent-Specific Model Routing

Configure different AI models for different Claude Code agents using agent frontmatter configuration.

## Overview

When you use the Task tool to spawn agents in Claude Code, you can configure each agent to use a specific model. This lets you optimize cost and performance:

- **Programming agents** → GLM-4.6 (unlimited $6/month)
- **Design agents** → Gemini 2.0 Flash (vision + creativity)
- **Research agents** → Perplexity (web search capabilities)
- **Writing agents** → Claude Opus (highest quality)

## How It Works

1. **Agent markdown files** contain YAML frontmatter with model specification
2. **Claude Code spawns agent** using the specified model
3. **Request hits CCProxy** at `http://localhost:4000`
4. **CCProxy routes** to the appropriate provider based on model name
5. **Provider responds** and result returns to agent

## Configuration Method

### Add Model to Agent Frontmatter

Edit your agent markdown files (typically in `~/.claude/agents/` or your PAI structure):

```markdown
---
name: engineer
model: glm-4.6
---

# Engineer Agent

Use this agent for professional software engineering expertise...
```

### Available Model Values

Use **exact model names** from your `config.yaml`:

```markdown
# Anthropic (via OAuth)
model: claude-sonnet-4-5-20250929
model: claude-opus-4-5-20251101
model: claude-haiku-4-5-20251001

# Z.ai GLM (unlimited $6/month)
model: glm-4.6
model: glm-4.5-air

# OpenRouter
model: deepseek-chat

# Google Gemini (if configured)
model: gemini-2.0-flash
model: gemini-1.5-pro

# OpenAI (if configured)
model: gpt-4o
model: gpt-4o-mini

# Ollama (local models - free, private)
model: llama3.1
model: codellama
model: mistral

# Special values
model: inherit          # Use same model as main conversation
model: sonnet          # Alias for default Sonnet
model: opus            # Alias for default Opus
model: haiku           # Alias for default Haiku
```

## Example Configurations

### Programming Agent → GLM-4.6

**agents/engineer.md:**
```markdown
---
name: engineer
model: glm-4.6
---

# Engineer Agent

Use this agent for professional software engineering expertise, high-quality code
implementation, debugging, and technical problem-solving.

## Routing Rationale
- GLM-4.6 provides unlimited tokens ($6/month)
- Good for large codebases and extended coding sessions
- Saves Claude Max session limits for interactive work
```

### UX/UI Agent → Gemini 2.0 Flash

**agents/ux-designer.md:**
```markdown
---
name: ux-designer
model: gemini-2.0-flash
---

# UX Designer Agent

Use this agent for UX/UI design work including user research, wireframing, mockups,
prototyping, and design systems.

## Routing Rationale
- Gemini excels at visual understanding and creative tasks
- Fast response times for iterative design work
- Multimodal capabilities for image analysis
```

### Research Agent → Perplexity

**agents/perplexity-researcher.md:**
```markdown
---
name: perplexity-researcher
model: perplexity-sonar
---

# Perplexity Research Agent

Use this agent when you need research done - crawling the web, finding answers,
gathering information, or solving problems through research.

## Routing Rationale
- Perplexity models have built-in web search
- Up-to-date information from live web sources
- Specialized for research tasks
```

### Premium Writing Agent → Claude Opus

**agents/writer.md:**
```markdown
---
name: writer
model: claude-opus-4-5-20251101
---

# Premium Writing Agent

Use this agent for high-quality writing, content creation, and editorial work.

## Routing Rationale
- Claude Opus provides highest quality output
- Best for client-facing content and important documents
- Worth using Claude Max credits for premium work
```

### Local Testing Agent → Ollama llama3.1

**agents/test-agent.md:**
```markdown
---
name: test-agent
model: llama3.1
---

# Test Agent (Local)

Use this agent for development, testing, and experimentation with completely free
local models.

## Routing Rationale
- Zero API costs - completely free
- Full privacy - data never leaves your machine
- Fast local inference (with GPU)
- Perfect for prototyping and testing
- No internet connection required
```

## Testing Agent Routing

### 1. Launch Claude Code with CCProxy

```powershell
cclaude
```

### 2. Spawn Agent and Verify Model

```
> Launch the engineer agent

# Check CCProxy logs to verify routing
```

### 3. Monitor Logs

```powershell
# In another terminal, watch CCProxy logs
Get-Content "C:\Users\$env:USERNAME\.ccproxy\litellm.log" -Wait -Tail 20
```

Look for log lines showing model routing:
```
INFO - Model: glm-4.6
INFO - Provider: anthropic/glm-4.6
INFO - API Base: https://open.bigmodel.cn/api/anthropic
```

## Important Notes

### Task Tool `model` Parameter is Broken

**DO NOT rely on this** (as of December 2025):

```python
# ❌ DOES NOT WORK - Bug in Claude Code
Task(
    subagent_type="engineer",
    model="glm-4.6",  # This gets ignored!
    prompt="Build authentication system"
)
```

**GitHub Issue**: [#12063](https://github.com/anthropics/claude-code/issues/12063)

**Use frontmatter instead**:
```markdown
---
name: engineer
model: glm-4.6
---
```

### Model Must Exist in config.yaml

The model specified in agent frontmatter **must be defined** in your `~/.ccproxy/config.yaml`:

```yaml
model_list:
  - model_name: glm-4.6
    litellm_params:
      model: anthropic/glm-4.6
      api_key: YOUR_API_KEY
      api_base: https://open.bigmodel.cn/api/anthropic
```

If the model isn't configured, you'll get an error:
```
LLM Provider NOT provided. You passed model=glm-4.6
```

### Routing Rules Still Apply

Even with agent-specific models, CCProxy routing rules can still override:

```yaml
# If this rule is enabled...
rules:
  - name: extended_thinking
    rule: ccproxy.rules.ThinkingRule

# ...thinking requests will route to the rule's model
# INSTEAD of the agent's configured model
```

**Best practice**: Disable broad routing rules when using agent-specific models, or make sure rules don't conflict with your agent configuration.

## Cost Optimization Strategies

### Strategy 1: Heavy Workers → Unlimited Models

```markdown
# Agents that do heavy token work
agents/engineer.md:       model: glm-4.6
agents/refactorer.md:     model: glm-4.6
agents/documenter.md:     model: glm-4.6
```

**Result**: Save Claude Max limits for interactive work

### Strategy 2: Specialized Models for Specialized Tasks

```markdown
# Use the best tool for each job
agents/designer.md:       model: gemini-2.0-flash   # Vision
agents/researcher.md:     model: perplexity-sonar   # Web search
agents/writer.md:         model: claude-opus         # Quality
agents/coder.md:          model: deepseek-chat       # Coding
```

**Result**: Optimize performance and cost per task type

### Strategy 3: Tiered Quality

```markdown
# Critical work → Claude Opus
agents/client-facing.md:  model: claude-opus

# Standard work → Claude Sonnet
agents/general.md:        model: claude-sonnet

# Background work → Cheaper models
agents/background.md:     model: glm-4.6
```

**Result**: Reserve premium models for premium work

## Adding New Providers for Agents

### 1. Add Model to config.yaml

```yaml
model_list:
  - model_name: gemini-2.0-flash
    litellm_params:
      model: gemini/gemini-2.0-flash
      api_key: os.environ/GEMINI_API_KEY
```

### 2. Set Environment Variable

```powershell
# Add to PowerShell profile
$env:GEMINI_API_KEY = "your-api-key-here"
```

### 3. Restart CCProxy

```powershell
ccproxy --config-dir "$env:USERPROFILE\.ccproxy" stop
ccproxy --config-dir "$env:USERPROFILE\.ccproxy" start --detach
```

### 4. Configure Agent

```markdown
---
name: ux-designer
model: gemini-2.0-flash
---
```

### 5. Test

```
> Launch UX designer agent
```

Check logs to verify Gemini is being called.

## Troubleshooting

### Agent Uses Wrong Model

**Symptom**: Agent uses Claude Sonnet instead of configured model

**Causes**:
1. Model not defined in `config.yaml`
2. Routing rule overriding agent model
3. Typo in model name (case-sensitive)

**Fix**:
```powershell
# Check config.yaml has the model
Get-Content "$env:USERPROFILE\.ccproxy\config.yaml" | Select-String "your-model-name"

# Check routing rules aren't overriding
Get-Content "$env:USERPROFILE\.ccproxy\ccproxy.yaml" | Select-String "rules:" -Context 10

# Verify model name spelling matches exactly
```

### Model Not Found Error

**Symptom**: `LLM Provider NOT provided. You passed model=xyz`

**Cause**: Model name in agent frontmatter doesn't match `model_name` in `config.yaml`

**Fix**: Check spelling and ensure model is defined:
```yaml
# config.yaml must have:
- model_name: xyz  # Exact match required
  litellm_params:
    model: provider/xyz
```

### OAuth Not Working

**Symptom**: Agent gets 401 Unauthorized with Anthropic models

**Cause**: OAuth token not being forwarded

**Fix**:
```yaml
# ccproxy.yaml must have:
oat_sources:
  anthropic: "powershell.exe -Command \"...\""

hooks:
  - ccproxy.hooks.forward_oauth  # Must be enabled
```

## Further Reading

- [PROVIDERS.md](PROVIDERS.md) - How to set up each provider
- [ROUTING-RULES.md](ROUTING-RULES.md) - Routing rules that may override agent models
- [CONFIGURATION.md](CONFIGURATION.md) - Full config file reference
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions

---

**Quick Reference:**
- Agent model specified in frontmatter: `model: glm-4.6`
- Must match `model_name` in `config.yaml`
- `Task()` tool `model` parameter is currently broken (use frontmatter)
- Routing rules can override agent models
- Check logs to verify correct routing
