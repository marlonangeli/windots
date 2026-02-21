[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot "common\logging.ps1")

$jiraTokenPath = Join-Path $HOME '.jira_access_token'
if (Test-Path $jiraTokenPath) {
    Log-Warn "Found legacy token file: $jiraTokenPath"
    Log-Warn "Move this token to Bitwarden and delete the file."
    if (Get-Command bw -ErrorAction SilentlyContinue) {
        Log-Info "Example: bw create item --category=login --name 'Jira Access Token'"
    }
}

$gitConfig = Join-Path $HOME '.gitconfig'
if (Test-Path $gitConfig) {
    $hasLegacy = Select-String -Path $gitConfig -Pattern 'tfstoken\s*=' -Quiet
    if ($hasLegacy) {
        Log-Warn "Legacy tfstoken found in .gitconfig. Remove and rotate credential."
    }
}

Log-Info "Secret migration checks complete."
