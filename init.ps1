[CmdletBinding()]
param(
    [ValidateSet("full", "clean")]
    [string]$Mode = "full",
    [switch]$SkipBaseInstall,
    [switch]$UseSymlinkAI,
    [switch]$SkipSecretsChecks,
    [switch]$AutoApply
)

$ErrorActionPreference = "Stop"

$repo = "marlonangeli/windots"
$installerUrl = "https://raw.githubusercontent.com/$repo/main/scripts/install-from-repo.ps1"

Write-Host "Bootstrapping $repo ..." -ForegroundColor Cyan
Write-Host "Installer: $installerUrl" -ForegroundColor DarkGray

$installer = Invoke-RestMethod -Uri $installerUrl
if ([string]::IsNullOrWhiteSpace($installer)) {
    throw "Failed to download installer from $installerUrl"
}

& ([scriptblock]::Create($installer)) `
    -Repo $repo `
    -Mode $Mode `
    -SkipBaseInstall:$SkipBaseInstall `
    -UseSymlinkAI:$UseSymlinkAI `
    -SkipSecretsChecks:$SkipSecretsChecks `
    -AutoApply:$AutoApply
