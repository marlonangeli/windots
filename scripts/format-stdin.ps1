[CmdletBinding()]
param(
    [string]$Path,
    [string]$SettingsPath = (Join-Path $PSScriptRoot "psscriptanalyzer.psd1")
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Write-FormatterOutput {
    [CmdletBinding()]
    param([AllowNull()][string]$Content)

    if ($null -eq $Content) {
        return
    }

    [Console]::Out.Write(($Content -replace "`r`n", "`n"))
}

function Test-WindotsFormatterTarget {
    [CmdletBinding()]
    param([string]$CandidatePath)

    if ([string]::IsNullOrWhiteSpace($CandidatePath)) {
        return $true
    }

    $repoRoot = Split-Path -Parent $PSScriptRoot
    try {
        $fullPath = [System.IO.Path]::GetFullPath($CandidatePath)
        $relativePath = [System.IO.Path]::GetRelativePath($repoRoot, $fullPath)
    }
    catch {
        return $true
    }

    if ([System.IO.Path]::IsPathRooted($relativePath) -or $relativePath.StartsWith("..")) {
        return $false
    }

    $normalizedPath = $relativePath -replace "\\", "/"
    return $normalizedPath -eq "install.ps1" -or $normalizedPath -match '^(scripts|modules|tests)/.*\.(ps1|psm1|psd1)$'
}

$source = [Console]::In.ReadToEnd() -replace "`r`n", "`n"
if (-not (Test-WindotsFormatterTarget -CandidatePath $Path)) {
    Write-FormatterOutput -Content $source
    return
}

if (-not (Get-Command Invoke-Formatter -ErrorAction SilentlyContinue)) {
    throw "Invoke-Formatter not found. Install with: Install-Module PSScriptAnalyzer -Scope CurrentUser"
}

$settings = $null
if (-not [string]::IsNullOrWhiteSpace($SettingsPath)) {
    $settingsCandidate = if ([System.IO.Path]::IsPathRooted($SettingsPath)) {
        $SettingsPath
    }
    else {
        Join-Path $PSScriptRoot $SettingsPath
    }

    if (Test-Path -LiteralPath $settingsCandidate) {
        $settings = (Resolve-Path -LiteralPath $settingsCandidate).Path
    }
}

$formatArgs = @{ ScriptDefinition = $source }
if ($settings) {
    $formatArgs.Settings = $settings
}

Write-FormatterOutput -Content (Invoke-Formatter @formatArgs)
