# claude-code-ollama

Setup walkthrough. Click the screen to play.

https://github.com/user-attachments/assets/daa8227f-1256-4d70-9d75-d34fa75b750f

Point Claude Code at Ollama Cloud model `kimi-k3`. All setup values live in `.env` on your machine. The API key is never committed.

The setup script writes `%USERPROFILE%\.claude\settings.json` on Windows and `~/.claude/settings.json` on macOS and Linux. The first run keeps an existing settings file as `settings.json.bak`.

## 1. Run setup

From the repo root:

| System | One step |
| --- | --- |
| Windows | Double-click `setup.bat` |
| macOS | Double-click `setup.command` |
| Linux | `chmod +x setup.sh && ./setup.sh` |

When `.env` has no API key, setup explains that this repo is designed for Ollama Cloud, then asks you to choose a provider. The choices are Ollama Cloud, Ollama on this computer, Moonshot (Kimi), Z.AI (GLM), MiniMax, DeepSeek, OpenRouter, Anthropic, OpenAI, Azure OpenAI, Azure AI Foundry, Google AI Studio, and Other. Ollama Cloud uses `https://ollama.com` and model `kimi-k3`. Every other choice asks you to type the API endpoint and model name before the key. The key is hidden while you type. A later run keeps the existing `.env`. `.env.example` lists the variables and is not edited.

The script then writes Claude Code settings from `.env`. It installs Claude Code when `claude` is missing, and updates it when a newer version is available. Windows uses WinGet. macOS and Linux use `claude update`, or the [native installer](https://code.claude.com/docs/en/setup) when Claude Code is not installed.

## 2. Start Claude Code

Quit any Claude Code session that is already open. Open a new terminal in your project directory and run:

```bash
claude
```

A new session uses the model from `ANTHROPIC_MODEL` in `.env`. Setup tells Claude Code that this model has a 1 million token context window, and points the Opus, Sonnet, Haiku, Fable, and subagent aliases at the same model.
