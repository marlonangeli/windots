[CmdletBinding()]
param(
    [ValidateSet("bootstrap", "apply", "update", "restore", "validate")]
    [string]$Command = "update",

    [ValidateSet("full", "clean")]
    [string]$Mode = "full",

    [string[]]$Modules,

    [switch]$SkipInstall,
    [switch]$SkipMise,
    [switch]$UseSymlinkAI,
    [switch]$SkipSecretsChecks,
    [switch]$NoPrompt,
    [switch]$WhatIf,

    [string]$RestoreConfigPath
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

. (Join-Path $PSScriptRoot "common\logging.ps1")
. (Join-Path $PSScriptRoot "common\state.ps1")

$preflightPath = Join-Path $PSScriptRoot "common\preflight.ps1"
if (Test-Path $preflightPath) {
    . $preflightPath
}

$bootstrapPath = Join-Path $PSScriptRoot "bootstrap.ps1"
$validatePath = Join-Path $PSScriptRoot "validate.ps1"

if (-not (Test-Path $bootstrapPath)) { throw "Missing bootstrap script: $bootstrapPath" }
if (-not (Test-Path $validatePath)) { throw "Missing validate script: $validatePath" }

function Invoke-PreflightForAction {
    param([ValidateSet("install", "update", "restore")][string]$Action)

    if ($WhatIf) {
        return
    }

    if (Get-Command Invoke-WindotsPreflight -ErrorAction SilentlyContinue) {
        Invoke-WindotsPreflight -Action $Action
    }
}

function Invoke-ChezmoiCommand {
    param([Parameter(Mandatory)][string[]]$Args)

    if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
        throw "chezmoi not found in PATH"
    }

    if ($WhatIf) {
        Log-Info ("WhatIf: would run 'chezmoi {0}'" -f ($Args -join " "))
        return
    }

    & chezmoi @Args
    if ($LASTEXITCODE -ne 0) {
        throw "chezmoi $($Args -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function Assert-ChezmoiInitialized {
    if ($WhatIf) {
        return
    }

    if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
        throw "chezmoi not found in PATH"
    }

    $sourcePath = chezmoi source-path 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sourcePath)) {
        throw "chezmoi source is not initialized. Run install flow first."
    }

    $resolved = $sourcePath.Trim().Trim('"')
    if (-not (Test-Path $resolved)) {
        throw "chezmoi source path not found: $resolved"
    }
}

function Invoke-BootstrapWorkflow {
    param([bool]$SkipInstallFlag)

    $bootstrapArgs = @{
        Mode = $Mode
        SkipInstall = $SkipInstallFlag
        SkipMise = [bool]$SkipMise
        UseSymlinkAI = [bool]$UseSymlinkAI
        NoPrompt = [bool]$NoPrompt
        IncludeSecretsChecks = (-not [bool]$SkipSecretsChecks)
        WhatIf = [bool]$WhatIf
    }

    if ($Modules -and $Modules.Count -gt 0) {
        $bootstrapArgs.Modules = $Modules
    }

    & $bootstrapPath @bootstrapArgs
    if (-not $?) {
        throw "bootstrap failed"
    }
}

function Invoke-Validation {
    if ($WhatIf) {
        Log-Info "WhatIf: would run scripts/validate.ps1"
        return
    }

    & $validatePath
    if (-not $?) {
        throw "validate.ps1 failed"
    }
}

function Invoke-ChezmoiVerify {
    Log-Step "Running chezmoi verify"
    Invoke-ChezmoiCommand -Args @("verify")
}

function Get-RestoreConfigValue {
    param(
        [Parameter(Mandatory)][object]$Object,
        [Parameter(Mandatory)][string[]]$PropertyNames
    )

    if (-not $Object) {
        return $null
    }

    foreach ($name in $PropertyNames) {
        $prop = $Object.PSObject.Properties | Where-Object { $_.Name -ieq $name } | Select-Object -First 1
        if ($prop) {
            return $prop.Value
        }
    }

    return $null
}

function Resolve-RestoreConfigPath {
    if (-not [string]::IsNullOrWhiteSpace($RestoreConfigPath)) {
        return $RestoreConfigPath
    }

    if (Get-Command Get-WindotsStateFilePath -ErrorAction SilentlyContinue) {
        return (Get-WindotsStateFilePath -Name "restore")
    }

    $stateBase = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $HOME ".local\\share" }
    return (Join-Path $stateBase "windots\\state\\restore.json")
}

function Set-ChezmoiEnvFromRestoreConfig {
    param(
        [object]$ChezmoiData,
        [object]$SecretEnv
    )

    $mappings = @(
        @{ Key = "name"; Alt = @("name"); Env = "CHEZMOI_NAME" },
        @{ Key = "email"; Alt = @("email"); Env = "CHEZMOI_EMAIL" },
        @{ Key = "github_username"; Alt = @("github_username", "githubUsername", "github"); Env = "CHEZMOI_GITHUB_USERNAME" },
        @{ Key = "azure_org"; Alt = @("azure_org", "azureOrg"); Env = "CHEZMOI_AZURE_ORG" },
        @{ Key = "azure_project"; Alt = @("azure_project", "azureProject"); Env = "CHEZMOI_AZURE_PROJECT" }
    )

    foreach ($mapping in $mappings) {
        $envKeyName = Get-RestoreConfigValue -Object $SecretEnv -PropertyNames $mapping.Alt
        $value = ""

        if (-not [string]::IsNullOrWhiteSpace($envKeyName)) {
            $value = [Environment]::GetEnvironmentVariable($envKeyName, "Process")
            if ([string]::IsNullOrWhiteSpace($value)) {
                $value = [Environment]::GetEnvironmentVariable($envKeyName, "User")
            }
            if ([string]::IsNullOrWhiteSpace($value)) {
                throw "Restore config requires environment variable '$envKeyName' for '$($mapping.Key)'"
            }
        }
        else {
            $resolved = Get-RestoreConfigValue -Object $ChezmoiData -PropertyNames $mapping.Alt
            if (-not [string]::IsNullOrWhiteSpace($resolved)) {
                $value = $resolved
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($value)) {
            [Environment]::SetEnvironmentVariable($mapping.Env, $value, "Process")
        }
    }
}

function Invoke-RestoreWorkflow {
    Invoke-PreflightForAction -Action "restore"

    $configPath = Resolve-RestoreConfigPath
    if (-not (Test-Path $configPath)) {
        throw "Restore config not found: $configPath"
    }

    $json = Get-Content -Path $configPath -Raw -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($json)) {
        throw "Restore config is empty: $configPath"
    }

    try {
        $config = $json | ConvertFrom-Json
    }
    catch {
        throw "Restore config is not valid JSON: $configPath. $($_.Exception.Message)"
    }

    $installer = Get-RestoreConfigValue -Object $config -PropertyNames @("installer")
    $chezmoiData = Get-RestoreConfigValue -Object $config -PropertyNames @("chezmoiData", "chezmoi_data")
    $secretEnv = Get-RestoreConfigValue -Object $config -PropertyNames @("secretEnv", "secret_env")

    Set-ChezmoiEnvFromRestoreConfig -ChezmoiData $chezmoiData -SecretEnv $secretEnv

    $installPath = Join-Path $repoRoot "install.ps1"
    if (-not (Test-Path $installPath)) {
        throw "install.ps1 not found in repository root: $installPath"
    }

    $installArgs = @{
        Action = "install"
        Repo = "marlonangeli/windots"
        Branch = "main"
        Mode = $Mode
        AutoApply = $true
        NoPrompt = $true
    }

    $repoValue = Get-RestoreConfigValue -Object $installer -PropertyNames @("repo")
    if (-not [string]::IsNullOrWhiteSpace($repoValue)) {
        $installArgs.Repo = $repoValue
    }

    $branchValue = Get-RestoreConfigValue -Object $installer -PropertyNames @("branch")
    if (-not [string]::IsNullOrWhiteSpace($branchValue)) {
        $installArgs.Branch = $branchValue
    }

    $refValue = Get-RestoreConfigValue -Object $installer -PropertyNames @("ref")
    if (-not [string]::IsNullOrWhiteSpace($refValue)) {
        $installArgs.Ref = $refValue
    }

    $localRepoPathValue = Get-RestoreConfigValue -Object $installer -PropertyNames @("localRepoPath", "local_repo_path")
    if (-not [string]::IsNullOrWhiteSpace($localRepoPathValue)) {
        $installArgs.LocalRepoPath = $localRepoPathValue
    }

    $modeValue = Get-RestoreConfigValue -Object $installer -PropertyNames @("mode")
    if ($modeValue -in @("full", "clean")) {
        $installArgs.Mode = $modeValue
    }

    $modulesValue = Get-RestoreConfigValue -Object $installer -PropertyNames @("modules")
    if ($modulesValue) {
        $installArgs.Modules = @($modulesValue)
    }

    $skipBaseInstallValue = Get-RestoreConfigValue -Object $installer -PropertyNames @("skipBaseInstall", "skip_base_install")
    if ($skipBaseInstallValue) {
        $installArgs.SkipBaseInstall = [bool]$skipBaseInstallValue
    }

    $useSymlinkValue = Get-RestoreConfigValue -Object $installer -PropertyNames @("useSymlinkAI", "use_symlink_ai")
    if ($useSymlinkValue) {
        $installArgs.UseSymlinkAI = [bool]$useSymlinkValue
    }

    $skipSecretsValue = Get-RestoreConfigValue -Object $installer -PropertyNames @("skipSecretsChecks", "skip_secrets_checks")
    if ($skipSecretsValue) {
        $installArgs.SkipSecretsChecks = [bool]$skipSecretsValue
    }

    if ($WhatIf) {
        Log-Info ("WhatIf: would run install.ps1 with repo='{0}' branch='{1}' mode='{2}'" -f $installArgs.Repo, $installArgs.Branch, $installArgs.Mode)
        return
    }

    Log-Step "Running restore installer workflow"
    & $installPath @installArgs
    if (-not $?) {
        throw "install.ps1 restore workflow failed"
    }
}

switch ($Command) {
    "bootstrap" {
        Invoke-BootstrapWorkflow -SkipInstallFlag ([bool]$SkipInstall)
    }
    "apply" {
        Assert-ChezmoiInitialized
        Invoke-PreflightForAction -Action "update"
        Log-Step "Running chezmoi apply"
        Invoke-ChezmoiCommand -Args @("apply")
        Log-Step "Running validation"
        Invoke-Validation
        Invoke-ChezmoiVerify
    }
    "update" {
        Assert-ChezmoiInitialized
        Invoke-PreflightForAction -Action "update"
        Log-Step "Running chezmoi update"
        Invoke-ChezmoiCommand -Args @("update")

        $skipInstallForUpdate = if ($PSBoundParameters.ContainsKey("SkipInstall")) {
            [bool]$SkipInstall
        }
        else {
            $true
        }

        Log-Step "Running bootstrap workflow"
        Invoke-BootstrapWorkflow -SkipInstallFlag $skipInstallForUpdate
        Log-Step "Running validation"
        Invoke-Validation
        Invoke-ChezmoiVerify
    }
    "restore" {
        Invoke-RestoreWorkflow
    }
    "validate" {
        Log-Step "Running validation"
        Invoke-Validation
    }
}
