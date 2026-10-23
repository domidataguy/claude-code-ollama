#!/bin/sh
set -eu
cd "$(dirname "$0")"

dotenv() {
  name=$1
  value=""
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ""|\#*) continue ;;
    esac
    case "$line" in
      "$name"=*) value=${line#"$name"=} ;;
    esac
  done < .env
  value=$(printf '%s' "$value" | tr -d '\r')
  case "$value" in
    \"*\") value=${value#\"}; value=${value%\"} ;;
    \'*\') value=${value#\'}; value=${value%\'} ;;
  esac
  printf '%s' "$value"
}

reject_json() {
  rest=$(printf '%s' "$2" | tr -d '[:alnum:]._:/?=+-')
  if [ -n "$rest" ]; then
    echo "$1 contains a character that cannot be written into settings.json." >&2
    exit 1
  fi
}

key=""
base=""
model=""
context=""
use_foundry=""
if [ -f .env ]; then
  key=$(dotenv OLLAMA_API_KEY)
  base=$(dotenv ANTHROPIC_BASE_URL)
  model=$(dotenv ANTHROPIC_MODEL)
  context=$(dotenv CLAUDE_CODE_MAX_CONTEXT_TOKENS)
  use_foundry=$(dotenv CLAUDE_CODE_USE_FOUNDRY)
fi
read_hidden() {
  prompt=$1
  printf "%s: " "$prompt"
  stty -echo
  trap 'stty echo' EXIT INT TERM
  IFS= read -r hidden || true
  stty echo
  trap - EXIT INT TERM
  printf "\n"
  hidden=$(printf '%s' "$hidden" | tr -d '\r')
}

if [ -z "$key" ] || [ "$key" = "YOUR_OLLAMA_API_KEY" ]; then
  if [ ! -t 0 ]; then
    echo "Run setup in a terminal to choose a provider and enter an API key." >&2
    exit 1
  fi
  echo "This repo is designed for Ollama Cloud (https://ollama.com), model kimi-k3."
  echo "Choose an API provider. Any choice other than Ollama Cloud asks you to type the endpoint."
  echo "  1) Ollama Cloud (recommended)"
  echo "  2) Ollama on this computer (localhost)"
  echo "  3) Moonshot (Kimi)"
  echo "  4) Z.AI (GLM)"
  echo "  5) MiniMax"
  echo "  6) DeepSeek"
  echo "  7) OpenRouter"
  echo "  8) Anthropic"
  echo "  9) OpenAI"
  echo "  10) Azure OpenAI"
  echo "  11) Azure AI Foundry"
  echo "  12) Google AI Studio"
  echo "  13) Other"
  printf "Provider [1]: "
  IFS= read -r choice || true
  choice=$(printf '%s' "$choice" | tr -d '\r')
  [ -n "$choice" ] || choice=1
  provider_id=""
  provider_name=""
  provider_hint=""
  case "$choice" in
    1) provider_id=ollama-cloud; provider_name="Ollama Cloud"; provider_hint="https://ollama.com" ;;
    2) provider_id=ollama-local; provider_name="Ollama on this computer"; provider_hint="http://localhost:11434" ;;
    3) provider_id=moonshot; provider_name="Moonshot (Kimi)"; provider_hint="https://api.moonshot.ai/anthropic" ;;
    4) provider_id=zai; provider_name="Z.AI (GLM)"; provider_hint="https://api.z.ai/api/anthropic" ;;
    5) provider_id=minimax; provider_name="MiniMax"; provider_hint="https://api.minimax.io/anthropic" ;;
    6) provider_id=deepseek; provider_name="DeepSeek"; provider_hint="https://api.deepseek.com/anthropic" ;;
    7) provider_id=openrouter; provider_name="OpenRouter"; provider_hint="https://openrouter.ai/api" ;;
    8) provider_id=anthropic; provider_name="Anthropic"; provider_hint="https://api.anthropic.com" ;;
    9) provider_id=openai; provider_name="OpenAI"; provider_hint="https://api.openai.com/v1" ;;
    10) provider_id=azure-openai; provider_name="Azure OpenAI"; provider_hint="https://YOUR_RESOURCE.openai.azure.com" ;;
    11) provider_id=azure-foundry; provider_name="Azure AI Foundry"; provider_hint="https://YOUR_RESOURCE.services.ai.azure.com" ;;
    12) provider_id=google-ai-studio; provider_name="Google AI Studio"; provider_hint="https://generativelanguage.googleapis.com" ;;
    13) provider_id=other; provider_name="Other"; provider_hint="" ;;
    *) echo "Choose a provider from 1 to 13." >&2; exit 1 ;;
  esac
  if [ "$provider_id" = "ollama-cloud" ]; then
    base="https://ollama.com"
    model="kimi-k3"
    context="1000000"
  else
    echo "This repo is designed for Ollama Cloud. Type the API endpoint for ${provider_name}."
    if [ -n "$provider_hint" ]; then
      echo "Usual endpoint: ${provider_hint}"
    fi
    printf "API endpoint: "
    IFS= read -r base || true
    base=$(printf '%s' "$base" | tr -d '\r')
    if [ -z "$base" ]; then
      echo "An API endpoint is required when the provider is not Ollama Cloud." >&2
      exit 1
    fi
    printf "Model name: "
    IFS= read -r model || true
    model=$(printf '%s' "$model" | tr -d '\r')
    if [ -z "$model" ]; then
      echo "A model name is required." >&2
      exit 1
    fi
    if [ "$model" = "kimi-k3" ]; then
      context="1000000"
    else
      context="200000"
    fi
    if [ "$provider_id" = "azure-foundry" ]; then
      use_foundry="1"
    fi
  fi
  if [ "$provider_id" = "ollama-local" ]; then
    echo "Enter the API key. It is saved in .env and is not shown as you type. Press Enter to use ollama for a local server."
    read_hidden "API key"
    key=$hidden
    [ -n "$key" ] || key="ollama"
  else
    key_label="API key"
    if [ "$provider_id" = "ollama-cloud" ]; then
      key_label="Ollama Cloud API key"
    fi
    echo "Enter the ${key_label}. It is saved in .env and is not shown as you type."
    read_hidden "$key_label"
    key=$hidden
    if [ -z "$key" ] || [ "$key" = "YOUR_OLLAMA_API_KEY" ]; then
      echo "An API key is required." >&2
      exit 1
    fi
  fi
  reject_json "OLLAMA_API_KEY" "$key"
  reject_json "ANTHROPIC_BASE_URL" "$base"
  reject_json "ANTHROPIC_MODEL" "$model"
  reject_json "CLAUDE_CODE_MAX_CONTEXT_TOKENS" "$context"
  umask 077
  env_body="ANTHROPIC_BASE_URL=${base}
ANTHROPIC_MODEL=${model}
CLAUDE_CODE_MAX_CONTEXT_TOKENS=${context}
OLLAMA_API_KEY=${key}
"
  if [ "$use_foundry" = "1" ]; then
    env_body="${env_body}CLAUDE_CODE_USE_FOUNDRY=1
"
  fi
  printf '%s' "$env_body" > .env
  echo "Created .env"
fi
[ -n "$base" ] || base="https://ollama.com"
[ -n "$model" ] || model="kimi-k3"
[ -n "$context" ] || context="1000000"
reject_json "OLLAMA_API_KEY" "$key"
reject_json "ANTHROPIC_BASE_URL" "$base"
reject_json "ANTHROPIC_MODEL" "$model"
reject_json "CLAUDE_CODE_MAX_CONTEXT_TOKENS" "$context"
foundry_json=""
if [ "$use_foundry" = "1" ]; then
  foundry_json="    \"CLAUDE_CODE_USE_FOUNDRY\": \"1\",
    \"ANTHROPIC_FOUNDRY_BASE_URL\": \"${base}\",
    \"ANTHROPIC_FOUNDRY_API_KEY\": \"${key}\","
fi

dest_dir="${HOME}/.claude"
dest="${dest_dir}/settings.json"
mkdir -p "$dest_dir"
if [ -f "$dest" ] && [ ! -f "${dest}.bak" ]; then
  cp "$dest" "${dest}.bak"
  echo "Backed up existing settings to ${dest}.bak"
fi

cat > "${dest}.tmp" <<EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "${base}",
    "ANTHROPIC_MODEL": "${model}",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "${model}",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "${model}",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "${model}",
    "ANTHROPIC_DEFAULT_FABLE_MODEL": "${model}",
    "CLAUDE_CODE_SUBAGENT_MODEL": "${model}",
    "ANTHROPIC_CUSTOM_MODEL_OPTION": "${model}",
    "CLAUDE_CODE_MAX_CONTEXT_TOKENS": "${context}",
${foundry_json}
    "ANTHROPIC_AUTH_TOKEN": "${key}",
    "ANTHROPIC_API_KEY": "",
    "OLLAMA_API_KEY": "${key}"
  },
  "model": "${model}"
}
EOF
mv "${dest}.tmp" "$dest"
echo "Wrote $dest"

if command -v claude >/dev/null 2>&1; then
  echo "Checking whether Claude Code is the latest version..."
  claude update
else
  echo "Claude Code is not installed. Installing the latest version..."
  curl -fsSL https://claude.ai/install.sh | bash
fi

echo "Open a new terminal and run: claude"
