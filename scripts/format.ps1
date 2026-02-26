[CmdletBinding()]
param(
    [switch]$Check,
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

function Get-TargetFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$InputPaths,
        [Parameter(Mandatory)][string]$Root
    )

    $files = New-Object System.Collections.Generic.List[string]
    foreach ($item in $InputPaths) {
        if ([string]::IsNullOrWhiteSpace($item)) {
            continue
        }

        $candidate = Join-Path $Root $item
        if (-not (Test-Path -LiteralPath $candidate)) {
            continue
        }

        $resolved = (Resolve-Path -LiteralPath $candidate).Path
        if (Test-Path -LiteralPath $resolved -PathType Leaf) {
            if ($resolved -match "\.(ps1|psm1|psd1)$" -and -not $files.Contains($resolved)) {
                $files.Add($resolved)
            }
            continue
        }

        Get-ChildItem -LiteralPath $resolved -Recurse -File |
            Where-Object { $_.Extension -in @(".ps1", ".psm1", ".psd1") } |
            ForEach-Object {
                $full = $_.FullName
                if (-not $files.Contains($full)) {
                    $files.Add($full)
                }
            }
    }

    return @($files)
}

function Write-FileUtf8NoBom {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $normalized = $Content -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($Path, $normalized, [System.Text.UTF8Encoding]::new($false))
}

if (-not (Get-Command Invoke-Formatter -ErrorAction SilentlyContinue)) {
    throw "Invoke-Formatter not found. Install with: Install-Module PSScriptAnalyzer -Scope CurrentUser"
}

$files = Get-TargetFiles -InputPaths $Paths -Root $repoRoot
if (-not $files -or $files.Count -eq 0) {
    throw "No PowerShell files found to format."
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

$changed = New-Object System.Collections.Generic.List[string]
foreach ($filePath in $files) {
    $source = Get-Content -LiteralPath $filePath -Raw -ErrorAction Stop
    $formatArgs = @{ ScriptDefinition = $source }
    if ($settings) {
        $formatArgs.Settings = $settings
    }

    $formatted = Invoke-Formatter @formatArgs
    if ($formatted -eq $source) {
        continue
    }

    $relative = [System.IO.Path]::GetRelativePath($repoRoot, $filePath)
    $changed.Add($relative)

    if (-not $Check) {
        Write-FileUtf8NoBom -Path $filePath -Content $formatted
        Write-Host "formatted $relative"
    }
}

if ($Check) {
    if ($changed.Count -gt 0) {
        foreach ($item in $changed) {
            Write-Host "needs formatting: $item"
        }
        throw "Formatting check failed for $($changed.Count) file(s)."
    }

    Write-Host "Format check OK" -ForegroundColor Green
    return
}

if ($changed.Count -eq 0) {
    Write-Host "No formatting changes needed."
}
else {
    Write-Host "Formatted $($changed.Count) file(s)." -ForegroundColor Green
}
