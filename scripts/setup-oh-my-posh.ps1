[CmdletBinding()]
param(
    [string]$ThemeName = "catppuccin_mocha.omp.json",
    [string]$FontName = "JetBrainsMono"
)

$ErrorActionPreference = "Stop"

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
    Write-Warning "oh-my-posh not found. Install it first (winget: JanDeDobbeleer.OhMyPosh)."
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
    Write-Host "Theme not found locally, attempting to download: $ThemeName" -ForegroundColor Yellow
    $themeUrl = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$ThemeName"
    try {
        Invoke-WebRequest -Uri $themeUrl -OutFile $themePath
    }
    catch {
        Write-Warning "Failed to download theme from $themeUrl"
    }
}

$fontInstalled = Test-FontInstalled -Pattern "JetBrainsMono.*Nerd Font"
if (-not $fontInstalled) {
    Write-Host "Installing Nerd Font via oh-my-posh: $FontName" -ForegroundColor Yellow
    try {
        oh-my-posh font install $FontName
    }
    catch {
        Write-Warning "oh-my-posh font install failed. Falling back to winget package."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id DEVCOM.JetBrainsMonoNerdFont --exact --accept-source-agreements --accept-package-agreements
        }
    }
}

Write-Host "oh-my-posh ready. Theme path: $themePath" -ForegroundColor Green
Write-Host "If font was newly installed, restart Windows Terminal to apply font cache updates." -ForegroundColor Green
