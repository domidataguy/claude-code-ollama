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

$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path -LiteralPath $envFile)) {
    throw "Create .env from .env.example and set OLLAMA_API_KEY."
}

$vars = Read-DotEnv $envFile
$key = [string]$vars["OLLAMA_API_KEY"]
$base = [string]$vars["ANTHROPIC_BASE_URL"]
$model = [string]$vars["ANTHROPIC_MODEL"]
if ([string]::IsNullOrWhiteSpace($base)) { $base = "https://ollama.com" }
if ([string]::IsNullOrWhiteSpace($model)) { $model = "kimi-k3" }
if ([string]::IsNullOrWhiteSpace($key) -or $key -eq "YOUR_OLLAMA_API_KEY") {
    throw "Set OLLAMA_API_KEY in .env."
}
Assert-JsonValue "OLLAMA_API_KEY" $key
Assert-JsonValue "ANTHROPIC_BASE_URL" $base
Assert-JsonValue "ANTHROPIC_MODEL" $model

$rendered = @"
{
  "env": {
    "ANTHROPIC_BASE_URL": "$base",
    "ANTHROPIC_MODEL": "$model",
    "ANTHROPIC_AUTH_TOKEN": "$key",
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
