#!/bin/sh
set -eu
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "Create .env from .env.example and set OLLAMA_API_KEY." >&2
  exit 1
fi

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

key=$(dotenv OLLAMA_API_KEY)
base=$(dotenv ANTHROPIC_BASE_URL)
model=$(dotenv ANTHROPIC_MODEL)
[ -n "$base" ] || base="https://ollama.com"
[ -n "$model" ] || model="kimi-k3"

if [ -z "$key" ] || [ "$key" = "YOUR_OLLAMA_API_KEY" ]; then
  echo "Set OLLAMA_API_KEY in .env." >&2
  exit 1
fi
reject_json "OLLAMA_API_KEY" "$key"
reject_json "ANTHROPIC_BASE_URL" "$base"
reject_json "ANTHROPIC_MODEL" "$model"

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
