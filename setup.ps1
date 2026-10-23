$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

function Read-DotEnv {
    param([string]$Path)
    $map = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }
        $eq = $trimmed.IndexOf("=")
        if ($eq -lt 1) { continue }
        $name = $trimmed.Substring(0, $eq).Trim()
        $value = $trimmed.Substring($eq + 1).Trim()
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        $map[$name] = $value
    }
    return $map
}

function Assert-JsonValue {
    param([string]$Name, [string]$Value)
    if ($Value -notmatch '^[A-Za-z0-9._:/?=+-]+$') {
        throw "$Name contains a character that cannot be written into settings.json."
    }
}

function Read-HiddenText {
    param([string]$Prompt)
    $secure = Read-Host $Prompt -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return ([Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)).Trim()
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Read-ProviderChoice {
    Write-Host "This repo is designed for Ollama Cloud (https://ollama.com), model kimi-k3."
    Write-Host "Choose an API provider. Any choice other than Ollama Cloud asks you to type the endpoint."
    Write-Host "  1) Ollama Cloud (recommended)"
    Write-Host "  2) Ollama on this computer (localhost)"
    Write-Host "  3) Moonshot (Kimi)"
    Write-Host "  4) Z.AI (GLM)"
    Write-Host "  5) MiniMax"
    Write-Host "  6) DeepSeek"
    Write-Host "  7) OpenRouter"
    Write-Host "  8) Anthropic"
    Write-Host "  9) OpenAI"
    Write-Host "  10) Azure OpenAI"
    Write-Host "  11) Azure AI Foundry"
    Write-Host "  12) Google AI Studio"
    Write-Host "  13) Other"
    $choice = (Read-Host "Provider [1]").Trim()
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "1" }
    switch ($choice) {
        "1" { return [pscustomobject]@{ Id = "ollama-cloud"; Name = "Ollama Cloud"; Hint = "https://ollama.com" } }
        "2" { return [pscustomobject]@{ Id = "ollama-local"; Name = "Ollama on this computer"; Hint = "http://localhost:11434" } }
        "3" { return [pscustomobject]@{ Id = "moonshot"; Name = "Moonshot (Kimi)"; Hint = "https://api.moonshot.ai/anthropic" } }
        "4" { return [pscustomobject]@{ Id = "zai"; Name = "Z.AI (GLM)"; Hint = "https://api.z.ai/api/anthropic" } }
        "5" { return [pscustomobject]@{ Id = "minimax"; Name = "MiniMax"; Hint = "https://api.minimax.io/anthropic" } }
        "6" { return [pscustomobject]@{ Id = "deepseek"; Name = "DeepSeek"; Hint = "https://api.deepseek.com/anthropic" } }
        "7" { return [pscustomobject]@{ Id = "openrouter"; Name = "OpenRouter"; Hint = "https://openrouter.ai/api" } }
        "8" { return [pscustomobject]@{ Id = "anthropic"; Name = "Anthropic"; Hint = "https://api.anthropic.com" } }
        "9" { return [pscustomobject]@{ Id = "openai"; Name = "OpenAI"; Hint = "https://api.openai.com/v1" } }
        "10" { return [pscustomobject]@{ Id = "azure-openai"; Name = "Azure OpenAI"; Hint = "https://YOUR_RESOURCE.openai.azure.com" } }
        "11" { return [pscustomobject]@{ Id = "azure-foundry"; Name = "Azure AI Foundry"; Hint = "https://YOUR_RESOURCE.services.ai.azure.com" } }
        "12" { return [pscustomobject]@{ Id = "google-ai-studio"; Name = "Google AI Studio"; Hint = "https://generativelanguage.googleapis.com" } }
        "13" { return [pscustomobject]@{ Id = "other"; Name = "Other"; Hint = "" } }
        default { throw "Choose a provider from 1 to 13." }
    }
}

$envFile = Join-Path $PSScriptRoot ".env"
$vars = @{}
if (Test-Path -LiteralPath $envFile) {
    $vars = Read-DotEnv $envFile
}
$key = [string]$vars["OLLAMA_API_KEY"]
$base = [string]$vars["ANTHROPIC_BASE_URL"]
$model = [string]$vars["ANTHROPIC_MODEL"]
$context = [string]$vars["CLAUDE_CODE_MAX_CONTEXT_TOKENS"]
$useFoundry = [string]$vars["CLAUDE_CODE_USE_FOUNDRY"]
if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "YOUR_OLLAMA_API_KEY") {
    $provider = Read-ProviderChoice
    if ($provider.Id -eq "ollama-cloud") {
        $base = "https://ollama.com"
        $model = "kimi-k3"
        $context = "1000000"
    } else {
        Write-Host "This repo is designed for Ollama Cloud. Type the API endpoint for $($provider.Name)."
        if ($provider.Hint) { Write-Host "Usual endpoint: $($provider.Hint)" }
        $base = (Read-Host "API endpoint").Trim()
        if ([string]::IsNullOrWhiteSpace($base)) { throw "An API endpoint is required when the provider is not Ollama Cloud." }
        $model = (Read-Host "Model name").Trim()
        if ([string]::IsNullOrWhiteSpace($model)) { throw "A model name is required." }
        if ($model -eq "kimi-k3") { $context = "1000000" } else { $context = "200000" }
        if ($provider.Id -eq "azure-foundry") { $useFoundry = "1" }
    }
    if ($provider.Id -eq "ollama-local") {
        Write-Host "Enter the API key. It is saved in .env and is not shown as you type. Press Enter to use ollama for a local server."
        $key = Read-HiddenText "API key"
        if ([string]::IsNullOrWhiteSpace($key)) { $key = "ollama" }
    } else {
        $keyLabel = "API key"
        if ($provider.Id -eq "ollama-cloud") { $keyLabel = "Ollama Cloud API key" }
        Write-Host "Enter the $keyLabel. It is saved in .env and is not shown as you type."
        $key = Read-HiddenText $keyLabel
        if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "YOUR_OLLAMA_API_KEY") {
            throw "An API key is required."
        }
    }
    Assert-JsonValue "OLLAMA_API_KEY" $key
    Assert-JsonValue "ANTHROPIC_BASE_URL" $base
    Assert-JsonValue "ANTHROPIC_MODEL" $model
    Assert-JsonValue "CLAUDE_CODE_MAX_CONTEXT_TOKENS" $context
    $utf8Env = New-Object System.Text.UTF8Encoding $false
    $envText = "ANTHROPIC_BASE_URL=$base`nANTHROPIC_MODEL=$model`nCLAUDE_CODE_MAX_CONTEXT_TOKENS=$context`nOLLAMA_API_KEY=$key`n"
    if ($useFoundry -eq "1") { $envText += "CLAUDE_CODE_USE_FOUNDRY=1`n" }
    [System.IO.File]::WriteAllText($envFile, $envText, $utf8Env)
    Write-Host "Created .env"
}
if ([string]::IsNullOrWhiteSpace($base)) { $base = "https://ollama.com" }
if ([string]::IsNullOrWhiteSpace($model)) { $model = "kimi-k3" }
if ([string]::IsNullOrWhiteSpace($context)) { $context = "1000000" }
Assert-JsonValue "OLLAMA_API_KEY" $key
Assert-JsonValue "ANTHROPIC_BASE_URL" $base
Assert-JsonValue "ANTHROPIC_MODEL" $model
Assert-JsonValue "CLAUDE_CODE_MAX_CONTEXT_TOKENS" $context

$rendered = @"
{
  "env": {
    "ANTHROPIC_BASE_URL": "$base",
    "ANTHROPIC_MODEL": "$model",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "$model",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "$model",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "$model",
    "ANTHROPIC_DEFAULT_FABLE_MODEL": "$model",
    "CLAUDE_CODE_SUBAGENT_MODEL": "$model",
    "ANTHROPIC_CUSTOM_MODEL_OPTION": "$model",
    "CLAUDE_CODE_MAX_CONTEXT_TOKENS": "$context",
$(if ($useFoundry -eq "1") { @"
    "CLAUDE_CODE_USE_FOUNDRY": "1",
    "ANTHROPIC_FOUNDRY_BASE_URL": "$base",
    "ANTHROPIC_FOUNDRY_API_KEY": "$key",

"@ } else { "" })    "ANTHROPIC_AUTH_TOKEN": "$key",
    "ANTHROPIC_API_KEY": "",
    "OLLAMA_API_KEY": "$key"
  },
  "model": "$model"
}

"@

$destDir = Join-Path $env:USERPROFILE ".claude"
$dest = Join-Path $destDir "settings.json"
New-Item -ItemType Directory -Force -Path $destDir | Out-Null
if ((Test-Path -LiteralPath $dest) -and -not (Test-Path -LiteralPath ($dest + ".bak"))) {
    Copy-Item -LiteralPath $dest -Destination ($dest + ".bak") -Force
    Write-Host "Backed up existing settings to $dest.bak"
}

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($dest, $rendered.Replace("`r`n", "`n"), $utf8)
Write-Host "Wrote $dest"

function Test-ClaudeInstalled {
    $cmd = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $cmd -or -not $cmd.Source) { return $false }
    if ($cmd.Source -like "*.cmd") {
        $text = Get-Content -LiteralPath $cmd.Source -Raw -ErrorAction SilentlyContinue
        if ($text -match '"([^"]+)"') {
            return Test-Path -LiteralPath $Matches[1]
        }
    }
    return Test-Path -LiteralPath $cmd.Source
}

function Invoke-Winget {
    param([Parameter(Mandatory = $true)][string]$Command)
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "WinGet is required. Install App Installer, then run setup again."
    }
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & winget $Command --id Anthropic.ClaudeCode --exact --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Host
    $code = $LASTEXITCODE
    $ErrorActionPreference = $previous
    return $code
}

# WinGet returns this when the installed package is already the latest version.
$wingetAlreadyLatest = -1978335189

if (-not (Test-ClaudeInstalled)) {
    Write-Host "Claude Code is not installed. Installing the latest version..."
    $code = Invoke-Winget "install"
    if ($code -ne 0) { throw "WinGet install failed with exit code $code." }
} else {
    Write-Host "Checking whether Claude Code is the latest version..."
    $code = Invoke-Winget "upgrade"
    if ($code -eq 0) {
        Write-Host "Claude Code was updated to the latest version."
    } elseif ($code -eq $wingetAlreadyLatest) {
        Write-Host "Claude Code is already the latest version."
    } else {
        throw "WinGet upgrade failed with exit code $code."
    }
}

Write-Host "Open a new terminal and run: claude"
