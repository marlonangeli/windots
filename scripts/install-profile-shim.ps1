[CmdletBinding()]
param(
    [ValidateSet("install", "reset", "status")]
    [string]$Action = "install",

    [string]$BackupPath,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$targetProfile = $PROFILE.CurrentUserCurrentHost
$targetDir = Split-Path -Parent $targetProfile
$sourceRoot = Join-Path $HOME ".config\powershell"
$legacySourceRoot = Join-Path $HOME "home\.config\powershell"
$sourceProfile = Join-Path $sourceRoot "Microsoft.PowerShell_profile.ps1"
$legacySourceProfile = Join-Path $legacySourceRoot "Microsoft.PowerShell_profile.ps1"
$repoRoot = Split-Path -Parent $PSScriptRoot
$repoProfileRoot = Join-Path $repoRoot "home\dot_config\powershell"
$backupRoot = Join-Path $sourceRoot "profile-backups"
$metaFile = Join-Path $backupRoot "latest-backup.json"
$shimMarker = "Auto-generated shim. Do not place custom logic here."

function Ensure-BaseFolders {
    if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
    if (-not (Test-Path $sourceRoot)) { New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null }
    if (-not (Test-Path $backupRoot)) { New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null }
}

function Bootstrap-SourceProfile {
    if (-not (Test-Path $sourceProfile) -and (Test-Path $legacySourceProfile)) {
        if (-not (Test-Path $sourceRoot)) {
            New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null
        }
        Copy-Item -Path (Join-Path $legacySourceRoot "*") -Destination $sourceRoot -Recurse -Force
        Write-Host "Migrated legacy home/.config/powershell to ~/.config/powershell." -ForegroundColor Yellow
    }

    if (-not (Test-Path $sourceProfile) -and (Test-Path $repoProfileRoot)) {
        Copy-Item -Path (Join-Path $repoProfileRoot "*") -Destination $sourceRoot -Recurse -Force
        Write-Host "Bootstrapped ~/.config/powershell from repository template." -ForegroundColor Yellow
    }
}

function Is-ShimProfile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    $content = Get-Content $Path -Raw -ErrorAction SilentlyContinue
    return $content -match [regex]::Escape($shimMarker)
}

function Save-Backup {
    param([string]$Path)
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $dest = Join-Path $backupRoot ("Microsoft.PowerShell_profile.$timestamp.ps1")
    Copy-Item -Path $Path -Destination $dest -Force

    @{
        targetProfile = $targetProfile
        backupPath = $dest
        createdAt = (Get-Date).ToString("o")
    } | ConvertTo-Json | Set-Content -Path $metaFile -Encoding UTF8

    return $dest
}

function Install-Shim {
    Ensure-BaseFolders
    Bootstrap-SourceProfile

    if (Test-Path $targetProfile) {
        $isShim = Is-ShimProfile -Path $targetProfile
        if (-not $isShim) {
            if (-not $Force) {
                Write-Host "Existing profile detected: $targetProfile" -ForegroundColor Yellow
                $confirm = Read-Host "Continue, backup current profile, and install shim? (y/N)"
                if ($confirm -notin @("y", "Y", "yes", "YES")) {
                    Write-Host "Canceled by user. No changes made." -ForegroundColor Yellow
                    return
                }
            }

            $backup = Save-Backup -Path $targetProfile
            Write-Host "Backup created: $backup" -ForegroundColor Yellow
        }
    }

    $shim = @"
# Auto-generated shim. Do not place custom logic here.
# Real profile lives in: $sourceProfile
if (Test-Path "$sourceProfile") {
    . "$sourceProfile"
}
"@

    Set-Content -Path $targetProfile -Value $shim -Encoding UTF8
    Write-Host "Profile shim installed: $targetProfile" -ForegroundColor Green
    Write-Host "To rollback: pwsh ./scripts/install-profile-shim.ps1 -Action reset" -ForegroundColor Cyan
}

function Reset-Profile {
    Ensure-BaseFolders

    $selectedBackup = $BackupPath

    if (-not $selectedBackup -and (Test-Path $metaFile)) {
        $meta = Get-Content $metaFile -Raw | ConvertFrom-Json
        $selectedBackup = $meta.backupPath
    }

    if (-not $selectedBackup) {
        $latest = Get-ChildItem -Path $backupRoot -Filter "Microsoft.PowerShell_profile.*.ps1" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($latest) { $selectedBackup = $latest.FullName }
    }

    if (-not $selectedBackup -or -not (Test-Path $selectedBackup)) {
        Write-Warning "No backup found. Nothing to restore."
        Write-Host "Check backups in: $backupRoot" -ForegroundColor Yellow
        return
    }

    if (-not $Force) {
        Write-Host "Backup selected: $selectedBackup" -ForegroundColor Yellow
        $confirm = Read-Host "Restore this backup to $targetProfile ? (y/N)"
        if ($confirm -notin @("y", "Y", "yes", "YES")) {
            Write-Host "Canceled by user. No changes made." -ForegroundColor Yellow
            return
        }
    }

    Copy-Item -Path $selectedBackup -Destination $targetProfile -Force
    Write-Host "Profile restored from backup." -ForegroundColor Green
    Write-Host "If needed, reinstall shim later with: pwsh ./scripts/install-profile-shim.ps1 -Action install" -ForegroundColor Cyan
}

function Show-Status {
    Ensure-BaseFolders
    $exists = Test-Path $targetProfile
    $isShim = Is-ShimProfile -Path $targetProfile
    $latest = if (Test-Path $metaFile) { (Get-Content $metaFile -Raw | ConvertFrom-Json).backupPath } else { "" }

    Write-Host "Target profile: $targetProfile"
    Write-Host "Source profile: $sourceProfile"
    Write-Host "Target exists: $exists"
    Write-Host "Target is shim: $isShim"
    if ($latest) { Write-Host "Latest backup: $latest" }
    Write-Host "Reset command: pwsh ./scripts/install-profile-shim.ps1 -Action reset"
}

switch ($Action) {
    "install" { Install-Shim }
    "reset" { Reset-Profile }
    "status" { Show-Status }
}
