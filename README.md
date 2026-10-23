# claude-code-ollama

Install Claude Code if it is not already installed, then point it at Ollama Cloud model `kimi-k3`.

The API key is not in this repo. On the machine where you run the setup, put your Ollama Cloud key into `settings.example.json` in both `YOUR_OLLAMA_API_KEY` places.

The settings step replaces `%USERPROFILE%\.claude\settings.json` on Windows and `~/.claude/settings.json` on macOS and Linux. Copy that file aside first if you already have Claude Code settings you want to keep.

## 1. Install Claude Code

Skip this step when `claude` already runs in a terminal.

Official install methods: [Claude Code setup](https://code.claude.com/docs/en/setup). `npm install -g @anthropic-ai/claude-code` is deprecated.

### Windows (PowerShell)

Recommended:

```powershell
irm https://claude.ai/install.ps1 | iex
```

Or WinGet:

```powershell
winget install Anthropic.ClaudeCode
```

### macOS and Linux

Recommended:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

Or Homebrew:

```bash
brew install --cask claude-code
```

Close the terminal and open a new one so `claude` is on `PATH`.

## 2. Set the Ollama key and model

Clone this repo, `cd` into it, and edit `settings.example.json`. Then run the copy command for your system from the repo root.

### Windows (PowerShell)

Each statement ends with `;` so the block still runs if the paste drops the line breaks.

```powershell
$settings = Get-Content -Raw -Path ".\settings.example.json";
if ($settings -match "YOUR_OLLAMA_API_KEY") { throw "Replace YOUR_OLLAMA_API_KEY in settings.example.json first." };
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude" | Out-Null;
Copy-Item -LiteralPath ".\settings.example.json" -Destination "$env:USERPROFILE\.claude\settings.json" -Force
```

### macOS and Linux

```bash
if grep -q "YOUR_OLLAMA_API_KEY" ./settings.example.json; then
  echo "Replace YOUR_OLLAMA_API_KEY in settings.example.json first." >&2
  exit 1
fi
mkdir -p "$HOME/.claude"
cp ./settings.example.json "$HOME/.claude/settings.json"
```

## 3. Start Claude Code

Quit any Claude Code session that is already open. In your project directory, run:

```bash
claude
```

A new session uses Ollama Cloud model `kimi-k3` with no `--model` flag.
