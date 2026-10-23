# claude-code-ollama

Point Claude Code at Ollama Cloud model `kimi-k3`. All setup values live in `.env` on your machine. The API key is never committed.

The setup script writes `%USERPROFILE%\.claude\settings.json` on Windows and `~/.claude/settings.json` on macOS and Linux. The first run keeps an existing settings file as `settings.json.bak`.

## 1. Add your key

Copy the example env file and set `OLLAMA_API_KEY`. `ANTHROPIC_BASE_URL` and `ANTHROPIC_MODEL` are already set.

Windows:

```powershell
Copy-Item .env.example .env
```

macOS and Linux:

```bash
cp .env.example .env
```

## 2. Run setup

From the repo root:

| System | One step |
| --- | --- |
| Windows | Double-click `setup.bat` |
| macOS | Double-click `setup.command` |
| Linux | `chmod +x setup.sh && ./setup.sh` |

The script builds Claude Code settings from `.env`. It installs Claude Code when `claude` is missing, and updates it when a newer version is available. Windows uses WinGet. macOS and Linux use `claude update`, or the [native installer](https://code.claude.com/docs/en/setup) when Claude Code is not installed.

## 3. Start Claude Code

Quit any Claude Code session that is already open. Open a new terminal in your project directory and run:

```bash
claude
```

A new session uses the model from `ANTHROPIC_MODEL` in `.env`.
