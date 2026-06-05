if (-not (Test-InteractiveShell)) { return }

# Keep startup instant. Starship/mise activation can be useful, but running
# external init scripts here makes every shell pay that cost.
function global:prompt {
    $path = $ExecutionContext.SessionState.Path.CurrentLocation
    "PS $path> "
}

function Enable-StarshipPrompt {
    [CmdletBinding()]
    param()

    if (-not (Get-Command starship -ErrorAction SilentlyContinue)) {
        Write-Warning "starship not found in PATH."
        return $false
    }

    Invoke-ShellInitScript -Command "starship" -Arguments @("init", "powershell") | Out-Null
    return $true
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

if ($env:WINDOTS_STARSHIP -eq "1") {
    Enable-StarshipPrompt | Out-Null
}
