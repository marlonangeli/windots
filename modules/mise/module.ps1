[CmdletBinding()]
param()

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptsRoot = Join-Path $repoRoot "scripts"

. (Join-Path $scriptsRoot "common\logging.ps1")
. (Join-Path $repoRoot "modules\packages\manager.ps1")

function Update-WindotsProcessPath {
    [CmdletBinding()]
    param()

    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [Environment]::GetEnvironmentVariable("Path", "User")
    $combined = @($machine, $user) -join ";"
    if (-not [string]::IsNullOrWhiteSpace($combined)) {
        $env:Path = $combined
    }
}

function Invoke-MiseCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [string]$WorkingDirectory
    )

    if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
        Push-Location $WorkingDirectory
    }

    try {
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $output = & mise @Arguments 2>&1
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousPreference
        }

        return [pscustomobject]@{
            ExitCode = $exitCode
            Output = @($output)
        }
    }
    finally {
        if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
            Pop-Location
        }
    }
}

function Ensure-MiseAvailable {
    [CmdletBinding()]
    param(
        [switch]$NoPrompt
    )

    if (Get-Command mise -ErrorAction SilentlyContinue) {
        return $true
    }

    Update-WindotsProcessPath
    if (Get-Command mise -ErrorAction SilentlyContinue) {
        return $true
    }

    Log-Warn "[mise] command is not available in PATH yet."
    if ($NoPrompt) {
        return $false
    }

    Log-Option "Reload shell/terminal to refresh PATH for newly installed tools."
    $response = Read-WindotsInput -Prompt "Press Enter after reload to retry, or type 'skip'"
    if ($response -and $response.Trim().ToLowerInvariant() -eq "skip") {
        return $false
    }

    Update-WindotsProcessPath
    return ($null -ne (Get-Command mise -ErrorAction SilentlyContinue))
}

function Invoke-WindotsModuleMise {
    [CmdletBinding()]
    param(
        [hashtable]$Context = @{}
    )

    if ($Context.SkipMise) {
        Log-Info "[mise] Skipped because -SkipMise was set."
        return
    }

    if (-not $Context.SkipInstall) {
        $mode = if ($Context.Mode) { $Context.Mode } else { "full" }
        Ensure-WindotsModulePackages -Module "mise" -Mode $mode -WhatIf:$Context.WhatIf
    }

    $setupPath = Join-Path $PSScriptRoot "setup.ps1"
    if (-not (Test-Path $setupPath)) {
        throw "[mise] Missing script: $setupPath"
    }

    if ($Context.WhatIf) {
        Log-Info "[mise] WhatIf: would configure mise and install toolchain."
        return
    }

    & $setupPath
    if (-not $?) {
        throw "[mise] setup script failed"
    }

    if (-not (Ensure-MiseAvailable -NoPrompt:$Context.NoPrompt)) {
        Log-Warn "[mise] command not found after setup."
        return
    }

    $miseProjectConfig = Join-Path $repoRoot ".mise.toml"
    if (Test-Path $miseProjectConfig) {
        Log-Step "[mise] Trusting repository config"
        $trustResult = Invoke-MiseCommand -Arguments @("trust", $miseProjectConfig) -WorkingDirectory $repoRoot
        if ($trustResult.ExitCode -ne 0) {
            foreach ($line in $trustResult.Output) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    Log-Output "$line"
                }
            }
            Log-Warn "[mise] unable to trust repository config automatically."
        }
        else {
            Log-Success "[mise] repository config trusted."
        }
    }

    $miseConfig = Join-Path $HOME ".config\mise\config.toml"
    if (-not (Test-Path $miseConfig)) {
        Log-Warn "[mise] config not found: $miseConfig"
        return
    }

    Log-Step "[mise] Installing toolchain"
    $installResult = Invoke-MiseCommand -Arguments @("install") -WorkingDirectory $repoRoot
    if ($installResult.ExitCode -ne 0) {
        foreach ($line in $installResult.Output) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                Log-Output "$line"
            }
        }
        throw "[mise] mise install failed"
    }
    Log-Success "[mise] toolchain installed."

    $doctorResult = Invoke-MiseCommand -Arguments @("doctor") -WorkingDirectory $repoRoot
    foreach ($line in $doctorResult.Output) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            Log-Output "$line"
        }
    }
    if ($doctorResult.ExitCode -ne 0) {
        Log-Warn "[mise] mise doctor reported issues."
    }

    $listResult = Invoke-MiseCommand -Arguments @("ls") -WorkingDirectory $repoRoot
    foreach ($line in $listResult.Output) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            Log-Output "$line"
        }
    }
}
