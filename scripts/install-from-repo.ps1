[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Repo,

    [ValidateSet("full", "clean")]
    [string]$Mode = "full",

    [switch]$SkipBaseInstall,
    [switch]$UseSymlinkAI,
    [switch]$SkipSecretsChecks
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Ensure-WingetPackage {
    param([Parameter(Mandatory)][string]$Id)

    $installed = winget list --id $Id --exact --accept-source-agreements 2>$null
    if ($LASTEXITCODE -eq 0 -and $installed) {
        Write-Host "    already installed: $Id" -ForegroundColor DarkGray
        return
    }

    Write-Host "    installing: $Id" -ForegroundColor Yellow
    winget install --id $Id --exact --accept-source-agreements --accept-package-agreements
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found. Install App Installer first."
}

if (-not $SkipBaseInstall) {
    Write-Step "Installing base dependencies"
    $basePackages = @(
        "twpayne.chezmoi",
        "Git.Git",
        "Microsoft.PowerShell",
        "GitHub.cli"
    )

    foreach ($pkg in $basePackages) {
        Ensure-WingetPackage -Id $pkg
    }
}

if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    throw "chezmoi not found in PATH after install."
}

Write-Step "Applying repository via chezmoi ($Repo)"
chezmoi init --apply $Repo

$sourcePath = chezmoi source-path
if (-not (Test-Path $sourcePath)) {
    throw "Unable to resolve chezmoi source-path."
}

$bootstrapPath = Join-Path $sourcePath "scripts\bootstrap.ps1"
$validatePath = Join-Path $sourcePath "scripts\validate.ps1"
$migratePath = Join-Path $sourcePath "scripts\migrate-secrets.ps1"
$secretsDepsPath = Join-Path $sourcePath "scripts\check-secrets-deps.ps1"
$linkAiPath = Join-Path $sourcePath "scripts\link-ai-configs.ps1"

if (-not (Test-Path $bootstrapPath)) { throw "Bootstrap script not found: $bootstrapPath" }
if (-not (Test-Path $validatePath)) { throw "Validate script not found: $validatePath" }

Write-Step "Running bootstrap ($Mode)"
$bootstrapArgs = @("-Mode", $Mode)
if ($SkipBaseInstall) { $bootstrapArgs += "-SkipInstall" }
& $bootstrapPath @bootstrapArgs

if ($UseSymlinkAI -and (Test-Path $linkAiPath)) {
    Write-Step "Relinking AI config with symlinks"
    & $linkAiPath -UseSymlink
}

Write-Step "Running repository validation"
& $validatePath

if (-not $SkipSecretsChecks) {
    if (Test-Path $migratePath) {
        Write-Step "Running legacy secret migration checks"
        & $migratePath
    }

    if (Test-Path $secretsDepsPath) {
        Write-Step "Running secrets dependency checks"
        & $secretsDepsPath
    }
}

Write-Host ""
Write-Host "Setup completed." -ForegroundColor Green
Write-Host "Profile mode commands: pmode / pclean / pfull" -ForegroundColor Green
