[CmdletBinding()]
param()

$jiraTokenPath = Join-Path $HOME '.jira_access_token'
if (Test-Path $jiraTokenPath) {
    Write-Warning "Found legacy token file: $jiraTokenPath"
    Write-Host "Move this token to Bitwarden and delete the file." -ForegroundColor Yellow
    if (Get-Command bw -ErrorAction SilentlyContinue) {
        Write-Host "Example: bw create item --category=login --name 'Jira Access Token'" -ForegroundColor Cyan
    }
}

$gitConfig = Join-Path $HOME '.gitconfig'
if (Test-Path $gitConfig) {
    $hasLegacy = Select-String -Path $gitConfig -Pattern 'tfstoken\s*=' -Quiet
    if ($hasLegacy) {
        Write-Warning "Legacy tfstoken found in .gitconfig. Remove and rotate credential."
    }
}

Write-Host "Secret migration checks complete." -ForegroundColor Green
