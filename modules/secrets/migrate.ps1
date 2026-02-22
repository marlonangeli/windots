[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptsRoot = Join-Path $repoRoot "scripts"
. (Join-Path $scriptsRoot "common\logging.ps1")

$jiraTokenPath = Join-Path $HOME ".jira_access_token"
if (Test-Path $jiraTokenPath) {
    Log-Warn "Legacy token file detected: $jiraTokenPath"
    Log-Warn "Move this token to a secret manager and delete the local file."
    if (Get-Command bw -ErrorAction SilentlyContinue) {
        Log-Info "Example: bw create item --category=login --name 'Jira Access Token'"
    }
}

$gitConfig = Join-Path $HOME ".gitconfig"
if (Test-Path $gitConfig) {
    $hasLegacyToken = Select-String -Path $gitConfig -Pattern "tfstoken\\s*=" -Quiet
    if ($hasLegacyToken) {
        Log-Warn "Legacy tfstoken found in .gitconfig. Remove and rotate this credential."
    }
}

Log-Info "Secret migration checks complete."
