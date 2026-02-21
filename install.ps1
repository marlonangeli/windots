[CmdletBinding()]
param(
    [ValidateSet("full", "clean")]
    [string]$Mode = "full",

    [switch]$SkipBaseInstall,
    [switch]$UseSymlinkAI,
    [switch]$SkipSecretsChecks,
    [switch]$AutoApply,
    [switch]$NoPrompt,
    [string[]]$Modules,

    [string]$Repo = "marlonangeli/windots",
    [string]$Branch = "main",
    [string]$Ref,
    [string]$Host = "raw.githubusercontent.com",
    [switch]$RequireNonMain,
    [string]$LocalRepoPath
)

$ErrorActionPreference = "Stop"

function Assert-SafeRefName {
    param(
        [Parameter(Mandatory)][string]$Value,
        [Parameter(Mandatory)][string]$Label
    )

    if ($Value -notmatch '^[A-Za-z0-9._/-]+$') {
        throw "Invalid $Label '$Value'. Allowed chars: A-Z a-z 0-9 . _ / -"
    }
}

function Assert-SafeRepoName {
    param([Parameter(Mandatory)][string]$Value)

    if ($Value -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
        throw "Invalid Repo '$Value'. Expected format: <owner>/<repo>"
    }
}

Assert-SafeRepoName -Value $Repo
Assert-SafeRefName -Value $Branch -Label "Branch"
if (-not [string]::IsNullOrWhiteSpace($Ref)) {
    Assert-SafeRefName -Value $Ref -Label "Ref"
}

if ($RequireNonMain -and [string]::IsNullOrWhiteSpace($Ref) -and [string]::IsNullOrWhiteSpace($LocalRepoPath) -and $Branch -eq "main") {
    throw "-RequireNonMain set but Branch is 'main' and Ref is empty. Choose -Branch, -Ref, or -LocalRepoPath."
}

if (-not [string]::IsNullOrWhiteSpace($LocalRepoPath)) {
    if (-not (Test-Path $LocalRepoPath)) {
        throw "LocalRepoPath not found: $LocalRepoPath"
    }
}

$selectedRef = if ([string]::IsNullOrWhiteSpace($Ref)) { $Branch } else { $Ref }
$baseUrl = "https://$Host/$Repo/$selectedRef"
$installerUrl = "$baseUrl/scripts/install.ps1"

Write-Host "Bootstrapping $Repo ..." -ForegroundColor Cyan
Write-Host "Source selector: Branch='$Branch' Ref='$Ref' LocalRepoPath='$LocalRepoPath'" -ForegroundColor DarkGray
Write-Host "Installer: $installerUrl" -ForegroundColor DarkGray

$installer = Invoke-RestMethod -Uri $installerUrl -ErrorAction Stop
if ([string]::IsNullOrWhiteSpace($installer)) {
    throw "Failed to download installer from $installerUrl"
}

& ([scriptblock]::Create($installer)) `
    -Repo $Repo `
    -Branch $Branch `
    -Ref $Ref `
    -RequireNonMain:$RequireNonMain `
    -LocalRepoPath $LocalRepoPath `
    -Mode $Mode `
    -SkipBaseInstall:$SkipBaseInstall `
    -UseSymlinkAI:$UseSymlinkAI `
    -SkipSecretsChecks:$SkipSecretsChecks `
    -AutoApply:$AutoApply `
    -NoPrompt:$NoPrompt `
    -Modules $Modules
