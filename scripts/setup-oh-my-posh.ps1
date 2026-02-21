# TODO: definir valores padrao em arquivo de manifesto
[CmdletBinding()]
param(
    [string]$ThemeName = "catppuccin_mocha.omp.json",
    [string]$FontName = "JetBrainsMono"
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common\logging.ps1")

function Test-FontInstalled {
    param([Parameter(Mandatory)][string]$Pattern)

    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
        "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    )

    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { continue }
        $props = Get-ItemProperty -Path $p
        foreach ($item in $props.PSObject.Properties) {
            if ($item.Name -match $Pattern) {
                return $true
            }
        }
    }

    return $false
}

if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    Log-Warn "oh-my-posh not found. Install it first (winget: JanDeDobbeleer.OhMyPosh)."
    return
}

$themesPath = $env:POSH_THEMES_PATH
if ([string]::IsNullOrWhiteSpace($themesPath)) {
    $themesPath = Join-Path $env:LOCALAPPDATA "Programs\oh-my-posh\themes"
    $env:POSH_THEMES_PATH = $themesPath
}

if (-not (Test-Path $themesPath)) {
    New-Item -ItemType Directory -Path $themesPath -Force | Out-Null
}

$themePath = Join-Path $themesPath $ThemeName
if (-not (Test-Path $themePath)) {
    Log-Warn "Theme not found locally, attempting to download: $ThemeName"
    $themeUrl = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$ThemeName"
    try {
        Invoke-WebRequest -Uri $themeUrl -OutFile $themePath
    }
    catch {
        Log-Warn "Failed to download theme from $themeUrl"
    }
}

$fontInstalled = Test-FontInstalled -Pattern "JetBrainsMono.*Nerd Font"
if (-not $fontInstalled) {
    Log-Warn "Installing Nerd Font via oh-my-posh: $FontName"
    try {
        oh-my-posh font install $FontName
    }
    catch {
        Log-Warn "oh-my-posh font install failed. Falling back to winget package."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id DEVCOM.JetBrainsMonoNerdFont --exact --accept-source-agreements --accept-package-agreements
        }
    }
}

Log-Info "oh-my-posh ready. Theme path: $themePath"
Log-Info "If font was newly installed, restart Windows Terminal to apply font cache updates."

# TODO: ensure that oh-my-posh is configured in PROFILE, and that the theme is applied.
