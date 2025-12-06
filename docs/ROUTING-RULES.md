# Routing Rules Guide

Complete guide to CCProxy's intelligent routing system - automatically direct requests to optimal models based on request characteristics.

## Table of Contents

- [Overview](#overview)
- [How Routing Works](#how-routing-works)
- [Rule Types](#rule-types)
  - [ThinkingRule](#thinkingrule)
  - [TokenCountRule](#tokencountrule)
  - [MatchToolRule](#matchtoolrule)
  - [MatchModelRule](#matchmodelrule)
- [Rule Configuration](#rule-configuration)
- [Model Aliases](#model-aliases)
- [Use Cases](#use-cases)
- [Troubleshooting](#troubleshooting)

---

## Overview

**Routing rules automatically redirect requests** to different models based on:
- Extended thinking mode enabled
- Token count exceeds threshold
- Specific tools being used
- Model name pattern matching

**Why use routing?**
- **Cost optimization**: Route heavy tasks to cheaper/unlimited models
- **Performance**: Use specialized models for specialized tasks
- **Capacity management**: Avoid hitting Claude Max session limits
- **Automatic**: No manual model switching required

---

## How Routing Works

### Request Flow

```
1. User sends request
   ↓
2. Claude Code → ANTHROPIC_BASE_URL (http://localhost:4000)
   ↓
3. CCProxy receives request
   ↓
4. rule_evaluator hook: Checks each rule in order
   ↓
5. If rule matches → model_router hook: Rewrites model field
   ↓
6. LiteLLM routes to appropriate provider
   ↓
7. Response returns to user
```

### Rule Evaluation Order

Rules are evaluated **in the order they appear** in `ccproxy.yaml`:

```yaml
rules:
  - name: extended_thinking      # Checked first
  - name: high_token_count       # Checked second
  - name: web_search             # Checked third
  - name: think-mode             # Checked last
```

**First matching rule wins** - subsequent rules are skipped.

### Model Alias System

Rules route to **model aliases**, not directly to providers:

```yaml
# Rule routes to alias
rules:
  - name: high_token_count
    rule: ccproxy.rules.TokenCountRule

# Alias maps to actual model deployment
model_list:
  - model_name: high_token_count  # Must match rule name
    litellm_params:
      model: anthropic/glm-4.6
      api_key: YOUR_API_KEY
      api_base: https://open.bigmodel.cn/api/anthropic
```

---

## Rule Types

### ThinkingRule

**Routes requests with extended thinking enabled** to cheaper/unlimited models.

#### Configuration

```yaml
rules:
  - name: extended_thinking
    rule: ccproxy.rules.ThinkingRule
```

#### How It Works

Detects when Claude Code sends `thinking: {enabled: true}` in the request:

```json
{
  "model": "claude-sonnet-4-5-20250929",
  "thinking": {
    "enabled": true,
    "budget_tokens": 10000
  },
  "messages": [...]
}
```

When detected → routes to model alias `extended_thinking`.

#### Use Case

**Problem**: Extended thinking mode generates massive token counts
- Thinking tokens don't count toward output limits
- Can generate 10k-50k+ tokens per request
- Burns through Claude Max limits quickly

**Solution**: Route thinking requests to unlimited model

```yaml
# ccproxy.yaml
rules:
  - name: extended_thinking
    rule: ccproxy.rules.ThinkingRule

# config.yaml
model_list:
  - model_name: extended_thinking
    litellm_params:
      model: anthropic/glm-4.6  # Unlimited $6/month
      api_key: os.environ/GLM_API_KEY
      api_base: https://open.bigmodel.cn/api/anthropic
```

**Result**: Extended thinking uses GLM, stays within Claude Max limits for interactive work.

#### Testing

```powershell
cclaude
> Ask me a complex question requiring deep analysis
# (Claude Code may enable thinking automatically)
```

Check logs for routing:
```
INFO - Matched rule: extended_thinking (ThinkingRule)
INFO - Routing to model: anthropic/glm-4.6
```

#### ⚠️ Important Warning

**ThinkingRule matches EVERY request by default** because Claude Code always sends `thinking: {enabled: true}` in the request payload, even when not using extended thinking mode.

**This caused the issue you experienced** - all requests were routing to GLM instead of Claude.

**Recommendation**: Only enable ThinkingRule if you:
1. Frequently use extended thinking mode
2. Want all requests to route to the thinking model
3. Understand it will override other routing

**Better alternative**: Use agent-specific models or manual model switching.

---

### TokenCountRule

**Routes high-token requests** (>threshold) to models with high capacity.

#### Configuration

```yaml
rules:
  - name: high_token_count
    rule: ccproxy.rules.TokenCountRule
    params:
      threshold: 60000  # Tokens
```

#### How It Works

1. Counts tokens in all messages using tiktoken
2. If total > threshold → routes to alias `high_token_count`
3. Otherwise → continues to next rule

#### Use Case

**Problem**: Large context requests hit Claude Max hourly limits
- Reviewing entire codebases
- Processing long documents
- Multi-file analysis

**Solution**: Route high-token requests to unlimited model

```yaml
# ccproxy.yaml
rules:
  - name: high_token_count
    rule: ccproxy.rules.TokenCountRule
    params:
      threshold: 60000

# config.yaml
model_list:
  - model_name: high_token_count
    litellm_params:
      model: anthropic/glm-4.6
      api_key: os.environ/GLM_API_KEY
      api_base: https://open.bigmodel.cn/api/anthropic
```

**Result**: Large context → GLM, normal requests → Claude Sonnet

#### Threshold Recommendations

```yaml
threshold: 30000   # Conservative - routes most large contexts
threshold: 60000   # Balanced - routes very large contexts only
threshold: 100000  # Aggressive - routes only massive contexts
```

**Claude Max limits** (approximate):
- Sonnet: ~88k tokens per 5-hour window
- Opus: ~88k tokens per 5-hour window

#### Testing

```powershell
# Test with large file
cclaude
> Read and analyze all files in /path/to/large/codebase
```

Check logs:
```
INFO - Token count: 75432
INFO - Matched rule: high_token_count (TokenCountRule, threshold=60000)
INFO - Routing to model: anthropic/glm-4.6
```

---

### MatchToolRule

**Routes requests using specific tools** to appropriate models.

#### Configuration

```yaml
rules:
  - name: web_search
    rule: ccproxy.rules.MatchToolRule
    params:
      tool_name: WebSearch
```

#### How It Works

Detects when request includes tool use:

```json
{
  "tools": [
    {"type": "function", "function": {"name": "WebSearch"}},
    {"type": "function", "function": {"name": "Read"}},
  ]
}
```

If `WebSearch` present → routes to alias `web_search`.

#### Use Cases

##### Web Search → Perplexity

Perplexity models have built-in web search:

```yaml
# ccproxy.yaml
rules:
  - name: web_search
    rule: ccproxy.rules.MatchToolRule
    params:
      tool_name: WebSearch

# config.yaml
model_list:
  - model_name: web_search
    litellm_params:
      model: perplexity/llama-3.1-sonar-huge-128k-online
      api_key: os.environ/PERPLEXITY_API_KEY
```

**Result**: Web search tasks use Perplexity instead of Claude.

##### Code Execution → DeepSeek

DeepSeek excels at code:

```yaml
rules:
  - name: bash_execution
    rule: ccproxy.rules.MatchToolRule
    params:
      tool_name: Bash

model_list:
  - model_name: bash_execution
    litellm_params:
      model: openrouter/deepseek/deepseek-chat-v3.1
      api_key: os.environ/OPENROUTER_API_KEY
```

#### Available Tool Names

Common Claude Code tools:
- `WebSearch` - Web searching
- `Bash` - Shell commands
- `Read` - File reading
- `Edit` - File editing
- `Write` - File creation
- `Glob` - File pattern matching
- `Grep` - Content searching
- `Task` - Agent spawning

#### Multiple Tool Matching

Match any of multiple tools:

```yaml
# ⚠️ Current limitation: Can only match one tool per rule
# To match multiple tools, create multiple rules:

rules:
  - name: web_or_research
    rule: ccproxy.rules.MatchToolRule
    params:
      tool_name: WebSearch

  - name: web_fetch
    rule: ccproxy.rules.MatchToolRule
    params:
      tool_name: WebFetch
```

#### Testing

```powershell
cclaude
> Search the web for latest AI developments
```

Check logs:
```
INFO - Tools in request: ['WebSearch']
INFO - Matched rule: web_search (MatchToolRule, tool=WebSearch)
INFO - Routing to model: perplexity/llama-3.1-sonar-huge-128k-online
```

---

### MatchModelRule

**Routes based on model name pattern** (regex matching).

#### Configuration

```yaml
rules:
  - name: think-mode
    rule: ccproxy.rules.MatchModelRule
    params:
      model_name: ".*think.*"  # Regex pattern
```

#### How It Works

Uses regex to match the requested model name:

```python
if re.search(pattern, requested_model):
    route_to_alias(rule_name)
```

#### Use Cases

##### Think Mode Routing

**Problem**: Claude Code doesn't expose models with "think" in the name, but you want a shorthand for routing.

**Workaround**: Create custom model aliases that trigger routing.

```yaml
# ccproxy.yaml
rules:
  - name: think-mode
    rule: ccproxy.rules.MatchModelRule
    params:
      model_name: ".*think.*"

# config.yaml
model_list:
  # Trigger model (not actually used)
  - model_name: claude-sonnet-think
    litellm_params:
      model: anthropic/claude-sonnet-4-5-20250929
      # This config is ignored - rule routes to think-mode alias instead

  # Actual routing target
  - model_name: think-mode
    litellm_params:
      model: anthropic/glm-4.6
      api_key: os.environ/GLM_API_KEY
      api_base: https://open.bigmodel.cn/api/anthropic
```

**Usage**:
```powershell
/model claude-sonnet-think
> complex reasoning task
```

Routes to GLM-4.6 instead.

##### Long Context Routing

```yaml
rules:
  - name: long-context
    rule: ccproxy.rules.MatchModelRule
    params:
      model_name: ".*longContext.*"

model_list:
  - model_name: claude-sonnet-longContext
    litellm_params:
      model: anthropic/claude-sonnet-4-5-20250929

  - model_name: long-context
    litellm_params:
      model: anthropic/glm-4.6
      api_key: os.environ/GLM_API_KEY
      api_base: https://open.bigmodel.cn/api/anthropic
```

**Usage**:
```powershell
/model claude-sonnet-longContext
> analyze this 200k token codebase
```

#### Regex Pattern Examples

```yaml
# Match any model with "think"
model_name: ".*think.*"

# Match models starting with "long"
model_name: "^long.*"

# Match models ending with "context"
model_name: ".*context$"

# Match either "think" or "reason"
model_name: ".*(think|reason).*"

# Match exact string
model_name: "^claude-sonnet-custom$"
```

#### ⚠️ Limitation

**Claude Code doesn't allow custom model names in `/model` command** - you can only select from models defined in your config.

**This makes MatchModelRule less useful** than originally intended, since you can't just type `/model think` to trigger routing.

**Better alternatives**:
- Use agent-specific models (frontmatter)
- Use TokenCountRule or MatchToolRule
- Manually switch with `/model glm-4.6`

#### Testing

```powershell
/model claude-sonnet-think  # Must be defined in config.yaml
> complex task
```

Check logs:
```
INFO - Matched rule: think-mode (MatchModelRule, pattern=.*think.*)
INFO - Routing to model: anthropic/glm-4.6
```

---

## Rule Configuration

### Complete Example

```yaml
ccproxy:
  debug: true
  handler: "ccproxy.handler:CCProxyHandler"

  oat_sources:
    anthropic: "powershell.exe -Command \"...\""

  hooks:
    - ccproxy.hooks.rule_evaluator  # Required for rules
    - ccproxy.hooks.model_router    # Required for routing
    - ccproxy.hooks.forward_oauth

  default_model_passthrough: true  # Use original model if no rule matches

  rules:
    # Evaluated in order, first match wins

    # 1. High token requests → GLM (unlimited)
    - name: high_token_count
      rule: ccproxy.rules.TokenCountRule
      params:
        threshold: 60000

    # 2. Web search → Perplexity (web-connected)
    - name: web_search
      rule: ccproxy.rules.MatchToolRule
      params:
        tool_name: WebSearch

    # 3. Extended thinking → GLM (unlimited)
    # ⚠️ WARNING: Matches ALL requests - see ThinkingRule section
    # - name: extended_thinking
    #   rule: ccproxy.rules.ThinkingRule

    # 4. Custom model names → Custom routing
    - name: think-mode
      rule: ccproxy.rules.MatchModelRule
      params:
        model_name: ".*think.*"
```

### Corresponding Model Aliases

```yaml
model_list:
  # Default (no routing)
  - model_name: default
    litellm_params:
      model: claude-sonnet-4-5-20250929

  # Routing aliases (must match rule names)
  - model_name: high_token_count
    litellm_params:
      model: anthropic/glm-4.6
      api_key: os.environ/GLM_API_KEY
      api_base: https://open.bigmodel.cn/api/anthropic

  - model_name: web_search
    litellm_params:
      model: perplexity/llama-3.1-sonar-huge-128k-online
      api_key: os.environ/PERPLEXITY_API_KEY

  - model_name: extended_thinking
    litellm_params:
      model: anthropic/glm-4.6
      api_key: os.environ/GLM_API_KEY
      api_base: https://open.bigmodel.cn/api/anthropic

  - model_name: think-mode
    litellm_params:
      model: anthropic/glm-4.6
      api_key: os.environ/GLM_API_KEY
      api_base: https://open.bigmodel.cn/api/anthropic
```

---

## Model Aliases

### Why Aliases?

Aliases separate **rule logic** from **provider configuration**:

```yaml
# Rule = "WHEN to route"
rules:
  - name: high_token_count
    rule: ccproxy.rules.TokenCountRule

# Alias = "WHERE to route"
model_list:
  - model_name: high_token_count
    litellm_params:
      model: anthropic/glm-4.6
```

**Benefits**:
- Change provider without changing rules
- Reuse same provider for multiple rules
- Clear separation of concerns

### Alias Naming

**Alias name MUST match rule name**:

```yaml
# ❌ WRONG - Name mismatch
rules:
  - name: high_token_count

model_list:
  - model_name: high-token  # Doesn't match!

# ✅ CORRECT - Exact match
rules:
  - name: high_token_count

model_list:
  - model_name: high_token_count  # Matches!
```

### Default Passthrough

```yaml
ccproxy:
  default_model_passthrough: true
```

**When enabled**:
- If no rule matches → uses model requested by Claude Code
- Still requires model definition in `config.yaml`

**When disabled**:
- If no rule matches → uses `default` alias
- Must define `default` model in `config.yaml`

---

## Use Cases

### Use Case 1: Cost Optimization

**Goal**: Keep Claude Max usage for interactive work, route heavy tasks to unlimited model.

```yaml
rules:
  # High token → GLM ($6/month unlimited)
  - name: high_token_count
    rule: ccproxy.rules.TokenCountRule
    params:
      threshold: 60000

  # Everything else → Claude Max (OAuth)
  # (no rule needed if default_model_passthrough: true)
```

**Result**:
- Large codebases → GLM
- Normal chat → Claude Sonnet
- Stay within Claude Max limits

### Use Case 2: Specialized Models

**Goal**: Use the best model for each task type.

```yaml
rules:
  # Web search → Perplexity
  - name: web_search
    rule: ccproxy.rules.MatchToolRule
    params:
      tool_name: WebSearch

  # Coding tasks → DeepSeek
  - name: code_execution
    rule: ccproxy.rules.MatchToolRule
    params:
      tool_name: Bash

  # Everything else → Claude Sonnet
```

**Result**:
- Research tasks → Perplexity (web-connected)
- Coding → DeepSeek (specialized)
- General → Claude Sonnet (high quality)

### Use Case 3: Agent-Specific + Rule Routing

**Goal**: Combine agent frontmatter models with automatic routing.

```yaml
# Agent frontmatter
---
name: engineer
model: glm-4.6  # Usually uses GLM
---

# But route web search to Perplexity
rules:
  - name: web_search
    rule: ccproxy.rules.MatchToolRule
    params:
      tool_name: WebSearch
```

**Result**:
- Engineer agent normally uses GLM
- But when engineer does web search → Perplexity
- Rules override agent frontmatter

---

## Troubleshooting

### Rule Not Matching

**Symptom**: Request should match rule but doesn't route

**Debug**:
```yaml
ccproxy:
  debug: true  # Enable debug logging
```

Check logs for rule evaluation:
```
DEBUG - Evaluating rule: high_token_count
DEBUG - Token count: 45000, threshold: 60000
DEBUG - Rule did not match
```

**Common causes**:
1. Token count below threshold
2. Tool name spelling mismatch
3. Regex pattern doesn't match
4. Rule disabled (commented out)

### Unexpected Routing

**Symptom**: Request routes to wrong model

**Cause**: Earlier rule matched first

```yaml
rules:
  - name: extended_thinking     # ⚠️ Matches EVERYTHING
    rule: ccproxy.rules.ThinkingRule

  - name: high_token_count      # Never reached!
    rule: ccproxy.rules.TokenCountRule
```

**Fix**: Reorder rules or disable broad rules:
```yaml
rules:
  - name: high_token_count      # More specific first
  - name: web_search
  # - name: extended_thinking   # Disable if too broad
```

### Model Not Found Error

**Symptom**: `Model not found: high_token_count`

**Cause**: Alias not defined in `config.yaml`

**Fix**: Add matching model definition:
```yaml
model_list:
  - model_name: high_token_count  # Must match rule name
    litellm_params:
      model: anthropic/glm-4.6
      api_key: os.environ/GLM_API_KEY
      api_base: https://open.bigmodel.cn/api/anthropic
```

### All Requests Route to Same Model

**Symptom**: Everything routes to GLM (or other model)

**Cause**: ThinkingRule matches everything

**Fix**: Disable ThinkingRule:
```yaml
rules:
  # - name: extended_thinking  # Comment out
  #   rule: ccproxy.rules.ThinkingRule
```

---

## Further Reading

- [AGENT-ROUTING.md](AGENT-ROUTING.md) - Agent-specific model configuration
- [PROVIDERS.md](PROVIDERS.md) - How to set up each provider
- [CONFIGURATION.md](CONFIGURATION.md) - Full config file reference
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions

---

**Quick Reference:**
- **ThinkingRule**: Routes extended thinking requests (⚠️ matches ALL requests)
- **TokenCountRule**: Routes high-token requests (>threshold)
- **MatchToolRule**: Routes based on tool usage (WebSearch, Bash, etc.)
- **MatchModelRule**: Routes based on model name pattern (regex)
- Rules evaluated in order, first match wins
- Alias name must match rule name
- Use `debug: true` to troubleshoot routing
