# Provider Setup Guide

Complete setup instructions for all supported AI providers with CCProxy.

## Table of Contents

- [Anthropic Claude (OAuth)](#anthropic-claude-oauth)
- [Z.ai GLM](#zai-glm)
- [OpenRouter](#openrouter)
- [OpenAI](#openai)
- [Google Gemini (AI Studio)](#google-gemini-ai-studio)
- [Google Vertex AI](#google-vertex-ai)
- [Azure OpenAI](#azure-openai)
- [Perplexity](#perplexity)
- [Mistral AI](#mistral-ai)
- [Ollama (Local)](#ollama-local)

---

## Anthropic Claude (OAuth)

**Use your Claude Max subscription** ($100/month) with OAuth token forwarding.

### Prerequisites
- Claude Max subscription
- Claude Code CLI installed

### Setup

1. **Configure OAuth extraction** in `ccproxy.yaml`:

```yaml
oat_sources:
  anthropic: "powershell.exe -Command \"(Get-Content '$env:USERPROFILE\\.claude\\.credentials.json' | ConvertFrom-Json).claudeAiOauth.accessToken\""
```

2. **Enable OAuth forwarding hook** in `ccproxy.yaml`:

```yaml
hooks:
  - ccproxy.hooks.rule_evaluator
  - ccproxy.hooks.model_router
  - ccproxy.hooks.forward_oauth  # ← Must be enabled
```

3. **Add models** to `config.yaml`:

```yaml
model_list:
  - model_name: claude-sonnet-4-5-20250929
    litellm_params:
      model: anthropic/claude-sonnet-4-5-20250929
      api_base: https://api.anthropic.com
      # No api_key needed - OAuth handles authentication

  - model_name: claude-opus-4-5-20251101
    litellm_params:
      model: anthropic/claude-opus-4-5-20251101
      api_base: https://api.anthropic.com

  - model_name: claude-haiku-4-5-20251001
    litellm_params:
      model: anthropic/claude-haiku-4-5-20251001
      api_base: https://api.anthropic.com
```

4. **Test**:

```powershell
cclaude
/model claude-sonnet-4-5-20250929
> who are you?
```

### Notes
- OAuth token is extracted on CCProxy startup
- Token is forwarded in `Authorization` header to Anthropic API
- No API key needed in config files
- Uses your Claude Max session limits

---

## Z.ai GLM

**Unlimited coding plan** for $6/month - best for high-token tasks.

### Prerequisites
- Z.ai account: https://open.bigmodel.cn/
- Coding Plan subscription ($6/month unlimited)

### Setup

1. **Get API key**:
   - Login to https://open.bigmodel.cn/
   - Navigate to API Keys
   - Create new key

2. **Set environment variable**:

```powershell
# Add to PowerShell profile
$env:GLM_API_KEY = "your-api-key-here.xxxxxxxx"
```

3. **Add to `config.yaml`**:

```yaml
model_list:
  - model_name: glm-4.6
    litellm_params:
      model: anthropic/glm-4.6
      api_key: os.environ/GLM_API_KEY
      api_base: https://open.bigmodel.cn/api/anthropic

  - model_name: glm-4.5-air
    litellm_params:
      model: anthropic/glm-4.5-air
      api_key: os.environ/GLM_API_KEY
      api_base: https://open.bigmodel.cn/api/anthropic
```

4. **Restart CCProxy** and test:

```powershell
ccproxy --config-dir "$env:USERPROFILE\.ccproxy" stop
ccproxy --config-dir "$env:USERPROFILE\.ccproxy" start --detach

cclaude
/model glm-4.6
> write a python script to calculate fibonacci
```

### Notes
- GLM uses Anthropic-compatible API format
- `glm-4.6` = flagship model (best quality)
- `glm-4.5-air` = faster, cheaper fallback
- **Unlimited tokens** on coding plan - perfect for routing heavy tasks

---

## OpenRouter

**Access 100+ models** through a single API - DeepSeek, Llama, etc.

### Prerequisites
- OpenRouter account: https://openrouter.ai/

### Setup

1. **Get API key**:
   - Login to https://openrouter.ai/
   - Go to Keys section
   - Create new key

2. **Set environment variable**:

```powershell
$env:OPENROUTER_API_KEY = "sk-or-v1-xxxxxxxxxx"
```

3. **Add to `config.yaml`**:

```yaml
model_list:
  # DeepSeek - excellent for coding
  - model_name: deepseek-chat
    litellm_params:
      model: openrouter/deepseek/deepseek-chat-v3.1
      api_key: os.environ/OPENROUTER_API_KEY

  # Meta Llama
  - model_name: llama-3.3-70b
    litellm_params:
      model: openrouter/meta-llama/llama-3.3-70b-instruct
      api_key: os.environ/OPENROUTER_API_KEY

  # Any other OpenRouter model
  - model_name: qwen-2.5-72b
    litellm_params:
      model: openrouter/qwen/qwen-2.5-72b-instruct
      api_key: os.environ/OPENROUTER_API_KEY
```

4. **Test**:

```powershell
/model deepseek-chat
> explain async/await in javascript
```

### Notes
- Browse models: https://openrouter.ai/models
- Model naming: `openrouter/{provider}/{model-name}`
- Pay-per-use pricing
- No subscription required

---

## OpenAI

**GPT-4o, o1-preview, and other OpenAI models**.

### Prerequisites
- OpenAI account: https://platform.openai.com/
- API credits loaded

### Setup

1. **Get API key**:
   - Login to https://platform.openai.com/
   - Navigate to API Keys
   - Create new secret key

2. **Set environment variable**:

```powershell
$env:OPENAI_API_KEY = "sk-xxxxxxxxxxxxxxxx"
```

3. **Add to `config.yaml`**:

```yaml
model_list:
  - model_name: gpt-4o
    litellm_params:
      model: openai/gpt-4o
      api_key: os.environ/OPENAI_API_KEY

  - model_name: gpt-4o-mini
    litellm_params:
      model: openai/gpt-4o-mini
      api_key: os.environ/OPENAI_API_KEY

  - model_name: o1-preview
    litellm_params:
      model: openai/o1-preview
      api_key: os.environ/OPENAI_API_KEY
```

4. **Test**:

```powershell
/model gpt-4o
> what are the key differences between gpt-4o and claude?
```

### Notes
- Pay-per-use pricing (no subscriptions)
- o1-preview excels at reasoning tasks
- gpt-4o-mini is cost-effective for simple tasks

---

## Google Gemini (AI Studio)

**Free tier available** - simple API key authentication.

### Prerequisites
- Google account
- Gemini API key: https://aistudio.google.com/app/apikey

### Setup

1. **Get API key**:
   - Visit https://aistudio.google.com/app/apikey
   - Click "Create API Key"
   - Copy key

2. **Set environment variable**:

```powershell
$env:GEMINI_API_KEY = "AIzaSyxxxxxxxxxxxxxxxxxx"
```

3. **Add to `config.yaml`**:

```yaml
model_list:
  - model_name: gemini-2.0-flash
    litellm_params:
      model: gemini/gemini-2.0-flash
      api_key: os.environ/GEMINI_API_KEY

  - model_name: gemini-1.5-pro
    litellm_params:
      model: gemini/gemini-1.5-pro
      api_key: os.environ/GEMINI_API_KEY

  # 2M token context window
  - model_name: gemini-1.5-pro-002
    litellm_params:
      model: gemini/gemini-1.5-pro-002
      api_key: os.environ/GEMINI_API_KEY
```

4. **Test**:

```powershell
/model gemini-2.0-flash
> describe this image: [paste image]
```

### Notes
- Free tier: 15 requests/minute
- Gemini excels at multimodal tasks (vision + text)
- 2M token context window on 1.5-pro-002
- Great for design/creative work

---

## Google Vertex AI

**Enterprise Gemini** with GCP service account authentication.

### Prerequisites
- Google Cloud Platform account
- Vertex AI API enabled
- Service account with Vertex AI permissions

### Setup

1. **Create service account**:

```bash
gcloud iam service-accounts create ccproxy-vertex \
  --display-name="CCProxy Vertex AI"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:ccproxy-vertex@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"

gcloud iam service-accounts keys create vertex-key.json \
  --iam-account=ccproxy-vertex@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

2. **Set environment variable**:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\vertex-key.json"
```

3. **Add global Vertex settings** to `config.yaml`:

```yaml
litellm_settings:
  vertex_project: "your-gcp-project-id"
  vertex_location: "us-central1"
```

4. **Add models**:

```yaml
model_list:
  - model_name: vertex-gemini-2.5-pro
    litellm_params:
      model: vertex_ai/gemini-2.5-pro
      # Inherits vertex_project and vertex_location from litellm_settings

  - model_name: vertex-gemini-flash
    litellm_params:
      model: vertex_ai/gemini-2.0-flash
```

5. **Test**:

```powershell
/model vertex-gemini-2.5-pro
> analyze this codebase structure
```

### Notes
- Enterprise features (SLAs, compliance, etc.)
- Pay-per-use pricing
- Requires GCP account and billing enabled
- More setup complexity than AI Studio

---

## Azure OpenAI

**Enterprise OpenAI models** via Azure subscription.

### Prerequisites
- Azure subscription
- Azure OpenAI resource created
- Model deployments configured

### Setup

1. **Create Azure OpenAI resource**:
   - Azure Portal → Create Resource → Azure OpenAI
   - Note your resource name and region

2. **Deploy models**:
   - Go to Azure OpenAI Studio
   - Deploy models (e.g., gpt-4o, gpt-4-turbo)
   - Note deployment names

3. **Get API key**:
   - Resource → Keys and Endpoint
   - Copy Key 1

4. **Set environment variable**:

```powershell
$env:AZURE_OPENAI_API_KEY = "xxxxxxxxxxxxxxxx"
```

5. **Add to `config.yaml`**:

```yaml
model_list:
  - model_name: azure-gpt-4o
    litellm_params:
      model: azure/your-gpt4o-deployment-name
      api_base: https://your-resource.openai.azure.com/
      api_version: "2023-05-15"
      api_key: os.environ/AZURE_OPENAI_API_KEY

  - model_name: azure-gpt-4-turbo
    litellm_params:
      model: azure/your-gpt4turbo-deployment-name
      api_base: https://your-resource.openai.azure.com/
      api_version: "2023-05-15"
      api_key: os.environ/AZURE_OPENAI_API_KEY
```

6. **Test**:

```powershell
/model azure-gpt-4o
> what compliance features does azure openai provide?
```

### Notes
- Enterprise compliance (HIPAA, SOC 2, etc.)
- SLA guarantees
- Regional data residency
- More expensive than OpenAI direct

---

## Perplexity

**Web-connected models** for research and current information.

### Prerequisites
- Perplexity API account: https://www.perplexity.ai/

### Setup

1. **Get API key**:
   - Login to Perplexity
   - Navigate to API section
   - Create new key

2. **Set environment variable**:

```powershell
$env:PERPLEXITY_API_KEY = "pplx-xxxxxxxxxxxxxxxx"
```

3. **Add to `config.yaml`**:

```yaml
model_list:
  - model_name: perplexity-sonar
    litellm_params:
      model: perplexity/llama-3.1-sonar-huge-128k-online
      api_key: os.environ/PERPLEXITY_API_KEY

  - model_name: perplexity-sonar-pro
    litellm_params:
      model: perplexity/llama-3.1-sonar-large-128k-online
      api_key: os.environ/PERPLEXITY_API_KEY
```

4. **Test**:

```powershell
/model perplexity-sonar
> what are the latest developments in AI in 2025?
```

### Notes
- Built-in web search capabilities
- Returns citations and sources
- Great for research agents
- Models are always up-to-date with web information

---

## Mistral AI

**European AI alternative** with competitive pricing.

### Prerequisites
- Mistral AI account: https://mistral.ai/

### Setup

1. **Get API key**:
   - Login to Mistral AI
   - Navigate to API Keys
   - Create new key

2. **Set environment variable**:

```powershell
$env:MISTRAL_API_KEY = "xxxxxxxxxxxxxxxx"
```

3. **Add to `config.yaml`**:

```yaml
model_list:
  - model_name: mistral-large
    litellm_params:
      model: mistral/mistral-large-latest
      api_key: os.environ/MISTRAL_API_KEY

  - model_name: mistral-medium
    litellm_params:
      model: mistral/mistral-medium-latest
      api_key: os.environ/MISTRAL_API_KEY
```

4. **Test**:

```powershell
/model mistral-large
> explain how mistral differs from other llms
```

### Notes
- European data residency
- Competitive pricing
- Good multilingual support
- Open-source friendly

---

## Ollama (Local)

**Free local models** - no API costs, complete privacy.

### Prerequisites
- Ollama installed: https://ollama.ai/

### Setup

1. **Install Ollama** (if not already installed):

```powershell
# Download from https://ollama.ai/download
# Or use winget:
winget install Ollama.Ollama
```

2. **Pull models**:

```powershell
ollama pull llama3.1:8b-instruct-q4_k_m
ollama pull codellama:13b
ollama pull mistral:7b
```

3. **Verify Ollama is running**:

```powershell
# Check if Ollama API is accessible
curl http://localhost:11434/api/tags
```

4. **Add to `config.yaml`**:

```yaml
model_list:
  - model_name: llama3.1
    litellm_params:
      model: ollama/llama3.1:8b-instruct-q4_k_m
      api_base: http://localhost:11434

  - model_name: codellama
    litellm_params:
      model: ollama/codellama:13b
      api_base: http://localhost:11434

  - model_name: mistral
    litellm_params:
      model: ollama/mistral:7b
      api_base: http://localhost:11434
```

5. **Test**:

```powershell
/model llama3.1
> what models are available in ollama?
```

### Notes
- **Completely free** - no API costs
- **Fully private** - data never leaves your machine
- Requires GPU for good performance
- Quality varies by model size
- Great for development and testing

---

## Environment Variables Summary

For easy setup, add all your API keys to PowerShell profile:

```powershell
# Add to: $PROFILE (PowerShell profile)

# Anthropic (OAuth - no key needed, but included for reference)
# Token extracted from: $env:USERPROFILE\.claude\.credentials.json

# Z.ai GLM
$env:GLM_API_KEY = "your-glm-key.xxxxxxxx"

# OpenRouter
$env:OPENROUTER_API_KEY = "sk-or-v1-xxxxxxxx"

# OpenAI
$env:OPENAI_API_KEY = "sk-xxxxxxxx"

# Google Gemini
$env:GEMINI_API_KEY = "AIzaSyxxxxxxxx"

# Google Vertex AI
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\vertex-key.json"

# Azure OpenAI
$env:AZURE_OPENAI_API_KEY = "xxxxxxxx"

# Perplexity
$env:PERPLEXITY_API_KEY = "pplx-xxxxxxxx"

# Mistral
$env:MISTRAL_API_KEY = "xxxxxxxx"
```

Then reload profile:
```powershell
. $PROFILE
```

---

## Testing All Providers

Use this script to verify all configured providers:

```powershell
# Test each provider
$models = @(
    "claude-sonnet-4-5-20250929",
    "glm-4.6",
    "deepseek-chat",
    "gpt-4o",
    "gemini-2.0-flash",
    "llama3.1"
)

foreach ($model in $models) {
    Write-Host "`nTesting $model..." -ForegroundColor Cyan
    # Launch cclaude and test model
}
```

---

## Further Reading

- [AGENT-ROUTING.md](AGENT-ROUTING.md) - Configure different models per agent
- [ROUTING-RULES.md](ROUTING-RULES.md) - Automatic routing based on rules
- [CONFIGURATION.md](CONFIGURATION.md) - Full config file reference
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common setup issues
