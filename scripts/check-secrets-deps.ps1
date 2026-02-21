[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

. (Join-Path $PSScriptRoot "common\logging.ps1")

function Write-Status {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][bool]$Ok,
        [Parameter(Mandatory)][string]$Message
    )

    $state = if ($Ok) { "OK" } else { "WARN" }
    $color = if ($Ok) { "Green" } else { "Yellow" }
    Write-Host ("[{0}] {1} - {2}" -f $state, $Name, $Message) -ForegroundColor $color
}

Log-Step "Checking secret-related dependencies and safeguards..."

$bw = $null -ne (Get-Command bw -ErrorAction SilentlyContinue)
$bwMessage = if ($bw) { "installed" } else { "optional, but recommended for runtime secret retrieval" }
Write-Status -Name "Bitwarden CLI (bw)" -Ok $bw -Message $bwMessage

$jira = $null -ne (Get-Command jira -ErrorAction SilentlyContinue)
$jiraMessage = if ($jira) { "installed" } else { "optional, only needed for Jira worklog integration" }
Write-Status -Name "Jira CLI (jira)" -Ok $jira -Message $jiraMessage

$gitignorePath = Join-Path $repoRoot ".gitignore"
$chezmoiIgnorePath = Join-Path $repoRoot "home\.chezmoiignore"

if (-not (Test-Path $gitignorePath)) {
    Write-Status -Name ".gitignore" -Ok $false -Message "file not found"
} else {
    $gitignore = Get-Content $gitignorePath -Raw
    $hasCore = @("**/auth.json", "**/*.token", "**/.jira_access_token", "home/dot_ssh/id_*") | ForEach-Object {
        $gitignore -match [regex]::Escape($_)
    }
    $ok = -not ($hasCore -contains $false)
    $gitignoreMessage = if ($ok) { "core secret patterns present" } else { "missing one or more core ignore patterns" }
    Write-Status -Name ".gitignore secret rules" -Ok $ok -Message $gitignoreMessage
}

if (-not (Test-Path $chezmoiIgnorePath)) {
    Write-Status -Name "home/.chezmoiignore" -Ok $false -Message "file not found"
} else {
    $chezIgnore = Get-Content $chezmoiIgnorePath -Raw
    $ok = $chezIgnore -match "home/dot_codex/auth\.json"
    if (-not $ok) {
        $ok = $chezIgnore -match "dot_codex/auth\.json"
    }
    $chezMessage = if ($ok) { "codex auth ignored in source import" } else { "missing codex auth ignore rule" }
    Write-Status -Name "home/.chezmoiignore codex auth" -Ok $ok -Message $chezMessage
}

$jiraCfg = Join-Path $repoRoot "home\dot_config\jira\.config.yml.tmpl"
if (Test-Path $jiraCfg) {
    $content = Get-Content $jiraCfg -Raw
    $ok = $content -match 'token:\s*""'
    $jiraTemplateMessage = if ($ok) { "empty token placeholder only" } else { "review token field in Jira template" }
    Write-Status -Name "Jira template token placeholder" -Ok $ok -Message $jiraTemplateMessage
}

Log-Info "Done."
