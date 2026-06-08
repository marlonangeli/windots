[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$Force,
    [switch]$Diff
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    throw "chezmoi not found in PATH. Install it first or run scripts/bootstrap.ps1."
}

[Environment]::SetEnvironmentVariable("WINDOTS_REPO_ROOT", $repoRoot, "User")
$env:WINDOTS_REPO_ROOT = $repoRoot

Write-Host "WINDOTS_REPO_ROOT=$repoRoot" -ForegroundColor Green

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

if ($Apply) {
    $chezmoiArgs = @("--source", $repoRoot, "apply")
    if ($Force) { $chezmoiArgs += "--force" }
    chezmoi @chezmoiArgs
    if ($LASTEXITCODE -ne 0) { throw "chezmoi apply failed with exit code $LASTEXITCODE" }
    return
}

if ($Diff) {
    chezmoi --source $repoRoot diff --no-pager
    if ($LASTEXITCODE -ne 0) { throw "chezmoi diff failed with exit code $LASTEXITCODE" }
    return
}

Write-Host "Local link configured. Use -Diff to preview or -Apply to materialize dotfiles." -ForegroundColor DarkGray
