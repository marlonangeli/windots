if (-not $PSVersionTable -or -not $PSVersionTable.PSVersion -or $PSVersionTable.PSVersion.Major -lt 7) {
    return
}

$script:WindotsProfileTimer = [System.Diagnostics.Stopwatch]::StartNew()

$profileRoot = if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    Split-Path -Parent $PROFILE
}
else {
    $PSScriptRoot
}

$global:__WindotsProfileRoot = $profileRoot
$global:__WindotsProfileDir = Join-Path $profileRoot "profile.d"

$profileMode = $env:POWERSHELL_PROFILE_MODE
if ([string]::IsNullOrWhiteSpace($profileMode)) { $profileMode = "full" }
$profileMode = $profileMode.Trim().ToLowerInvariant()
if ($profileMode -notin @("full", "clean")) { $profileMode = "full" }
$global:__WindotsProfileMode = $profileMode

$cleanScripts = @(
    "00-core.ps1",
    "10-env.ps1",
    "20-path.ps1",
    "30-prompt.ps1",
    "40-aliases.ps1",
    "80-ilegna.ps1"
)

$fullScripts = @(
    "50-git.ps1",
    "60-dev.ps1",
    "70-ai.ps1"
)

$scripts = if ($profileMode -eq "clean") { $cleanScripts } else { $cleanScripts + $fullScripts }
foreach ($scriptName in $scripts) {
    $scriptPath = Join-Path $global:__WindotsProfileDir $scriptName
    if (-not (Test-Path $scriptPath)) {
        if ($env:WINDOTS_PROFILE_DEBUG) { Write-Warning "profile.d missing: $scriptName" }
        continue
    }

    $scriptTimer = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        . $scriptPath
    }
    catch {
        Write-Warning "Failed to load profile.d/$scriptName. $($_.Exception.Message)"
    }
    finally {
        $scriptTimer.Stop()
        if ($env:WINDOTS_PROFILE_DEBUG) {
            Write-Host ("[profile] {0} {1}ms" -f $scriptName, $scriptTimer.ElapsedMilliseconds) -ForegroundColor DarkGray
        }
    }
}

$script:WindotsProfileTimer.Stop()
if ($env:WINDOTS_PROFILE_DEBUG) {
    Write-Host ("[profile] total {0}ms ({1})" -f $script:WindotsProfileTimer.ElapsedMilliseconds, $profileMode) -ForegroundColor DarkGray
}
