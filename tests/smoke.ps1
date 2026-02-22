[CmdletBinding()]
param(
    [string]$Repo = "marlonangeli/windots",
    [string]$Branch = "main",
    [string]$Ref,
    [string]$LocalRepoPath,
    [switch]$RequireNonMain,
    [switch]$AutoApply,
    [switch]$NoPrompt
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$installPath = Join-Path $repoRoot "install.ps1"
$bootstrapPath = Join-Path $repoRoot "scripts\bootstrap.ps1"
$validatePath = Join-Path $repoRoot "scripts\validate.ps1"

if (-not (Test-Path $installPath)) {
    throw "Installer not found: $installPath"
}

$installArgs = @{
    Repo = $Repo
    Branch = $Branch
    Mode = "full"
    AutoApply = [bool]$AutoApply
    NoPrompt = [bool]$NoPrompt
    RequireNonMain = [bool]$RequireNonMain
}

if (-not [string]::IsNullOrWhiteSpace($Ref)) {
    $installArgs.Ref = $Ref
}

if (-not [string]::IsNullOrWhiteSpace($LocalRepoPath)) {
    $installArgs.LocalRepoPath = $LocalRepoPath
}

Write-Host "==> Running installer smoke test" -ForegroundColor Cyan
& $installPath @installArgs
if ($LASTEXITCODE -ne 0) {
    throw "install.ps1 failed with exit code $LASTEXITCODE"
}

if (-not $AutoApply) {
    Write-Host "==> Running bootstrap (manual apply mode)" -ForegroundColor Cyan
    & $bootstrapPath -Mode full -NoPrompt:$NoPrompt
    if ($LASTEXITCODE -ne 0) {
        throw "bootstrap.ps1 failed with exit code $LASTEXITCODE"
    }

    Write-Host "==> Running validate" -ForegroundColor Cyan
    & $validatePath
    if ($LASTEXITCODE -ne 0) {
        throw "validate.ps1 failed with exit code $LASTEXITCODE"
    }
}

Write-Host "Smoke test completed successfully." -ForegroundColor Green
