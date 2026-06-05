[CmdletBinding()]
param()

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptsRoot = Join-Path $repoRoot "scripts"

. (Join-Path $scriptsRoot "common\logging.ps1")
. (Join-Path $scriptsRoot "common\guardrails.ps1")
. (Join-Path $repoRoot "modules\packages\manager.ps1")

function Set-WindotsChezmoiDataDefaults {
    [CmdletBinding()]
    param()

    if ([string]::IsNullOrWhiteSpace($env:CHEZMOI_NAME)) {
        $gitName = git config --global user.name 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitName)) {
            $env:CHEZMOI_NAME = $gitName.Trim()
        }
    }

    if ([string]::IsNullOrWhiteSpace($env:CHEZMOI_EMAIL)) {
        $gitEmail = git config --global user.email 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitEmail)) {
            $env:CHEZMOI_EMAIL = $gitEmail.Trim()
        }
    }
}

function Invoke-WindotsModuleCore {
    [CmdletBinding()]
    param(
        [hashtable]$Context = @{}
    )

    $mode = if ($Context.Mode) { $Context.Mode } else { "full" }
    $skipInstall = [bool]$Context.SkipInstall
    $whatIf = [bool]$Context.WhatIf

    if (-not $skipInstall) {
        Ensure-WindotsModulePackages -Module "core" -Mode $mode -WhatIf:$whatIf
    }

    Assert-WindotsRequiredCommand -Name "chezmoi" | Out-Null
    Assert-WindotsRequiredCommand -Name "git" | Out-Null
    Assert-WindotsRequiredCommand -Name "gum" | Out-Null

    if ($whatIf) {
        Log-Info "[core] WhatIf: would run 'chezmoi apply'."
        return
    }

    Log-Step "[core] Applying chezmoi state"
    Set-WindotsChezmoiDataDefaults

    $sourceRoot = if ($Context.RepoRoot) { $Context.RepoRoot } else { $repoRoot }
    chezmoi --source $sourceRoot apply
    if ($LASTEXITCODE -ne 0) {
        throw "[core] chezmoi apply failed with exit code $LASTEXITCODE"
    }
}
