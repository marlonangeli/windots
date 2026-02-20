# ============================================
# PowerShell Profile
# Modes:
# - full  (default): all modules
# - clean: core aliases/utilities only
# ============================================

$ProfileDir = Split-Path -Parent $PROFILE
$mode = $env:POWERSHELL_PROFILE_MODE
if ([string]::IsNullOrWhiteSpace($mode)) { $mode = "full" }
$mode = $mode.Trim().ToLowerInvariant()
if ($mode -notin @("full", "clean")) { $mode = "full" }
$global:__PSProfileMode = $mode

function Get-ProfileMode {
    [CmdletBinding()]
    param()
    $global:__PSProfileMode
}

function Set-ProfileMode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("full", "clean")]
        [string]$Mode
    )

    $normalized = $Mode.ToLowerInvariant()
    [Environment]::SetEnvironmentVariable("POWERSHELL_PROFILE_MODE", $normalized, "User")
    $env:POWERSHELL_PROFILE_MODE = $normalized
    Write-Host "Profile mode set to '$normalized'. Open a new shell to apply." -ForegroundColor Green
}

function Import-ProfileScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        Write-Warning "Profile script not found: $Path"
        return $false
    }

    try {
        return $true
    }
    catch {
        Write-Warning "Failed to load profile script: $Path. $_"
        return $false
    }
}

function Import-ProfileModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        Write-Warning "Profile module not found: $Path"
        return $false
    }

    try {
        Import-Module $Path -Force -DisableNameChecking -ErrorAction Stop
        return $true
    }
    catch {
        Write-Warning "Failed to import profile module: $Path. $_"
        return $false
    }
}

$configPath = "$ProfileDir\modules\config.ps1"
$aliasesPath = "$ProfileDir\modules\aliases.ps1"
$utilsPath = "$ProfileDir\modules\utils.ps1"

if (Import-ProfileScript $configPath) { . $configPath }
if (Import-ProfileScript $aliasesPath) { . $aliasesPath }
if (Import-ProfileScript $utilsPath) { . $utilsPath }

if ($mode -eq "full") {
    Import-ProfileModule "$ProfileDir\modules\worktrees.psm1" | Out-Null
    Import-ProfileModule "$ProfileDir\modules\time-tracker.psm1" | Out-Null
    Import-ProfileModule "$ProfileDir\modules\pr-workflow.psm1" | Out-Null
}
