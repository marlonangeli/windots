if (-not (Test-InteractiveShell)) { return }

$global:__WindotsStarshipCache = Join-Path $HOME ".cache\windots\starship-init.ps1"
$global:__WindotsStarshipLoaded = $false
$global:__WindotsStarshipAttempted = $false

function Invoke-WindotsFallbackPrompt {
    $path = $ExecutionContext.SessionState.Path.CurrentLocation
    "PS $path> "
}

function Enable-StarshipPrompt {
    [CmdletBinding()]
    param()

    if ($global:__WindotsStarshipLoaded) { return $true }

    if (Test-Path $global:__WindotsStarshipCache) {
        . $global:__WindotsStarshipCache
        $global:__WindotsStarshipLoaded = $true
        return $true
    }

    Write-Warning "Starship cache not found. Run: pwsh ./modules/themes/setup.ps1"
    return $false
}

function Enable-MiseActivation {
    [CmdletBinding()]
    param()

    if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
        Write-Warning "mise not found in PATH."
        return $false
    }

    Invoke-ShellInitScript -Command "mise" -Arguments @("activate", "pwsh") | Out-Null
    return $true
}

function global:prompt {
    if (-not $global:__WindotsStarshipLoaded -and -not $global:__WindotsStarshipAttempted) {
        $global:__WindotsStarshipAttempted = $true
        if (Enable-StarshipPrompt) {
            return (& $function:prompt)
        }
    }

    Invoke-WindotsFallbackPrompt
}
