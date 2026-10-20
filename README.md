# claude-code-ollama

User-level Claude Code settings that start every new `claude` session on Ollama Cloud model `kimi-k3`.

The API key is not in this repo. Put your Ollama Cloud key into `settings.example.json` on the machine where you run the setup, in both `YOUR_OLLAMA_API_KEY` places. Then run the command for your system from the repo root.

This replaces `%USERPROFILE%\.claude\settings.json` on Windows and `~/.claude/settings.json` on macOS and Linux. Copy that file aside first if you already have Claude Code settings you want to keep.

After it finishes, quit any open Claude Code session and start `claude` again.

## Windows (PowerShell)

```powershell
$settings = Get-Content -Raw -Path ".\settings.example.json"
if ($settings -match "YOUR_OLLAMA_API_KEY") { throw "Replace YOUR_OLLAMA_API_KEY in settings.example.json first." }
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude" | Out-Null
Copy-Item -LiteralPath ".\settings.example.json" -Destination "$env:USERPROFILE\.claude\settings.json" -Force
```

## macOS and Linux

```bash
if grep -q "YOUR_OLLAMA_API_KEY" ./settings.example.json; then
  echo "Replace YOUR_OLLAMA_API_KEY in settings.example.json first." >&2
  exit 1
fi
mkdir -p "$HOME/.claude"
cp ./settings.example.json "$HOME/.claude/settings.json"
```
