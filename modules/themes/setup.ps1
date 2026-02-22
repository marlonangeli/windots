[CmdletBinding()]
param(
    [string]$ThemeName = "catppuccin_mocha.omp.json",
    [string]$FontName = "JetBrainsMono"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptsRoot = Join-Path $repoRoot "scripts"
. (Join-Path $scriptsRoot "common\logging.ps1")
. (Join-Path $scriptsRoot "common\winget.ps1")

function Test-FontInstalled {
    param([Parameter(Mandatory)][string]$Pattern)

    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
        "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    )

    foreach ($path in $registryPaths) {
        if (-not (Test-Path $path)) { continue }
        $props = Get-ItemProperty -Path $path
        foreach ($property in $props.PSObject.Properties) {
            if ($property.Name -match $Pattern) {
                return $true
            }
        }
    }

    return $false
}

if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    Log-Warn "oh-my-posh not found. Install it first."
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
    $themeUrl = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$ThemeName"
    Log-Warn "Theme not found locally. Downloading: $themeUrl"
    Invoke-WebRequest -Uri $themeUrl -OutFile $themePath -ErrorAction Stop
}

$fontInstalled = Test-FontInstalled -Pattern "JetBrainsMono.*Nerd Font"
if (-not $fontInstalled) {
    Log-Warn "Nerd Font not detected. Installing '$FontName'."
    try {
        oh-my-posh font install $FontName
    }
    catch {
        Log-Warn "oh-my-posh font install failed. Falling back to winget package."
        Invoke-WingetInstall -Id "DEVCOM.JetBrainsMonoNerdFont"
    }
}

Log-Info "oh-my-posh ready. Theme path: $themePath"
