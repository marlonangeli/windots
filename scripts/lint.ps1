[CmdletBinding()]
param(
    [string[]]$Paths = @(
        "install.ps1",
        "scripts",
        "modules",
        "tests"
    ),
    [string]$SettingsPath = (Join-Path $PSScriptRoot "psscriptanalyzer.psd1")
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

function Resolve-TargetPaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$InputPaths,
        [Parameter(Mandatory)][string]$Root
    )

    $resolved = New-Object System.Collections.Generic.List[string]
    foreach ($item in $InputPaths) {
        if ([string]::IsNullOrWhiteSpace($item)) {
            continue
        }

        $candidate = Join-Path $Root $item
        if (-not (Test-Path -LiteralPath $candidate)) {
            continue
        }

        $full = (Resolve-Path -LiteralPath $candidate).Path
        if (-not $resolved.Contains($full)) {
            $resolved.Add($full)
        }
    }

    return $resolved.ToArray()
}

if (-not (Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue)) {
    throw "Invoke-ScriptAnalyzer not found. Install with: Install-Module PSScriptAnalyzer -Scope CurrentUser"
}

$targets = Resolve-TargetPaths -InputPaths $Paths -Root $repoRoot
if (-not $targets -or $targets.Count -eq 0) {
    throw "No valid lint targets were resolved."
}

$analyzerArgs = @{ Recurse = $true }

if (-not [string]::IsNullOrWhiteSpace($SettingsPath)) {
    $settingsCandidate = if ([System.IO.Path]::IsPathRooted($SettingsPath)) {
        $SettingsPath
    }
    else {
        Join-Path $PSScriptRoot $SettingsPath
    }

    if (Test-Path -LiteralPath $settingsCandidate) {
        $analyzerArgs.Settings = (Resolve-Path -LiteralPath $settingsCandidate).Path
    }
}

$issues = foreach ($target in $targets) {
    Invoke-ScriptAnalyzer -Path $target @analyzerArgs
}
if ($issues -and $issues.Count -gt 0) {
    $issues |
        Sort-Object ScriptName, Line, RuleName |
        Select-Object Severity, RuleName, ScriptName, Line, Message |
        Format-Table -AutoSize | Out-String | Write-Host

    throw "Lint failed with $($issues.Count) issue(s)."
}

Write-Host "Lint OK" -ForegroundColor Green
