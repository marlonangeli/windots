[CmdletBinding()]
param()

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptsRoot = Join-Path $repoRoot "scripts"

. (Join-Path $scriptsRoot "common\logging.ps1")
. (Join-Path $repoRoot "modules\packages\manager.ps1")

function Ensure-WindotsPowerShellModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$WhatIf,
        [switch]$NoPrompt,
        [switch]$Required
    )

    if (Get-Module -ListAvailable -Name $Name) {
        Log-Info "[shell] PowerShell module already installed: $Name"
        return
    }

    if ($WhatIf) {
        Log-Info "[shell] WhatIf: would install PowerShell module '$Name'"
        return
    }

    if (-not (Get-Command Install-Module -ErrorAction SilentlyContinue)) {
        if ($Required) {
            throw "[shell] Install-Module not available; cannot install required module '$Name'"
        }

        Log-Warn "[shell] Install-Module not available; skipping optional module '$Name'"
        return
    }

    try {
        $installArgs = @{
            Name = $Name
            Scope = "CurrentUser"
            Force = $true
            AllowClobber = $true
            ErrorAction = "Stop"
        }

        if ($NoPrompt) {
            $installArgs.Confirm = $false
        }

        Install-Module @installArgs
        Log-Info "[shell] PowerShell module installed: $Name"
    }
    catch {
        if ($Required) {
            throw "[shell] failed to install required PowerShell module '$Name': $($_.Exception.Message)"
        }

        Log-Warn "[shell] optional PowerShell module install failed: $Name. $($_.Exception.Message)"
    }
}

function Invoke-WindotsModuleShell {
    [CmdletBinding()]
    param(
        [hashtable]$Context = @{}
    )

    if (-not $Context.SkipInstall) {
        $mode = if ($Context.Mode) { $Context.Mode } else { "full" }
        Ensure-WindotsModulePackages -Module "shell" -Mode $mode -WhatIf:$Context.WhatIf

        Ensure-WindotsPowerShellModule -Name "PSReadLine" -WhatIf:$Context.WhatIf -NoPrompt:$Context.NoPrompt -Required
        Ensure-WindotsPowerShellModule -Name "Terminal-Icons" -WhatIf:$Context.WhatIf -NoPrompt:$Context.NoPrompt
        Ensure-WindotsPowerShellModule -Name "posh-git" -WhatIf:$Context.WhatIf -NoPrompt:$Context.NoPrompt
    }

    $scriptPath = Join-Path $PSScriptRoot "profile-shim.ps1"
    if (-not (Test-Path $scriptPath)) {
        throw "[shell] Missing script: $scriptPath"
    }

    if ($Context.WhatIf) {
        Log-Info "[shell] WhatIf: would install profile shim."
        return
    }

    Log-Step "[shell] Installing PowerShell profile shim"
    if ($Context.NoPrompt) {
        & $scriptPath -Action install -Force
    }
    else {
        & $scriptPath -Action install
    }

    if ($LASTEXITCODE -ne 0) {
        throw "[shell] profile shim install failed with exit code $LASTEXITCODE"
    }
}
