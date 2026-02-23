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
    param(
        [Parameter(Mandatory)][string[]]$RegistryPatterns,
        [Parameter(Mandatory)][string[]]$FilePatterns
    )

    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
        "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    )

    foreach ($path in $registryPaths) {
        if (-not (Test-Path $path)) { continue }
        $props = Get-ItemProperty -Path $path
        foreach ($property in $props.PSObject.Properties) {
            foreach ($pattern in $RegistryPatterns) {
                if ($property.Name -match $pattern) {
                    return $true
                }
            }
        }
    }

    $fontDirs = @(
        (Join-Path $env:WINDIR "Fonts"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts")
    )

    foreach ($fontDir in $fontDirs) {
        if (-not (Test-Path $fontDir)) { continue }

        foreach ($filePattern in $FilePatterns) {
            $match = Get-ChildItem -Path $fontDir -Filter $filePattern -File -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($match) {
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

$fontInstalled = Test-FontInstalled `
    -RegistryPatterns @("JetBrainsMono.*Nerd Font", "JetBrainsMono.*\bNF(M|P)?\b") `
    -FilePatterns @("JetBrainsMonoNerdFont-*.ttf", "JetBrainsMono*Nerd*Font*.ttf", "JetBrainsMono*NF*.ttf")
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
