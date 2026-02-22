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
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptsRoot = Join-Path $repoRoot "scripts"
$repoProfileRoot = Join-Path $repoRoot "home\dot_config\powershell"
$backupRoot = Join-Path $sourceRoot "profile-backups"
$metaFile = Join-Path $backupRoot "latest-backup.json"
$shimMarker = "Auto-generated shim. Do not place custom logic here."

. (Join-Path $scriptsRoot "common\logging.ps1")

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
        Log-Warn "Migrated legacy home/.config/powershell to ~/.config/powershell."
    }

    if (-not (Test-Path $sourceProfile) -and (Test-Path $repoProfileRoot)) {
        Copy-Item -Path (Join-Path $repoProfileRoot "*") -Destination $sourceRoot -Recurse -Force
        Log-Warn "Bootstrapped ~/.config/powershell from repository template."
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
                Log-Warn "Existing profile detected: $targetProfile"
                $confirm = Read-Host "Continue, backup current profile, and install shim? (y/N)"
                if ($confirm -notin @("y", "Y", "yes", "YES")) {
                    Log-Warn "Canceled by user. No changes made."
                    return
                }
            }

            $backup = Save-Backup -Path $targetProfile
            Log-Warn "Backup created: $backup"
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
    Log-Info "Profile shim installed: $targetProfile"
    Log-Info "To rollback: pwsh ./modules/shell/profile-shim.ps1 -Action reset"
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
        Log-Warn "No backup found. Nothing to restore."
        Log-Warn "Check backups in: $backupRoot"
        return
    }

    if (-not $Force) {
        Log-Warn "Backup selected: $selectedBackup"
        $confirm = Read-Host "Restore this backup to $targetProfile ? (y/N)"
        if ($confirm -notin @("y", "Y", "yes", "YES")) {
            Log-Warn "Canceled by user. No changes made."
            return
        }
    }

    Copy-Item -Path $selectedBackup -Destination $targetProfile -Force
    Log-Info "Profile restored from backup."
    Log-Info "If needed, reinstall shim with: pwsh ./modules/shell/profile-shim.ps1 -Action install"
}

function Show-Status {
    Ensure-BaseFolders
    $exists = Test-Path $targetProfile
    $isShim = Is-ShimProfile -Path $targetProfile
    $latest = if (Test-Path $metaFile) { (Get-Content $metaFile -Raw | ConvertFrom-Json).backupPath } else { "" }

    Log-Info "Target profile: $targetProfile"
    Log-Info "Source profile: $sourceProfile"
    Log-Info "Target exists: $exists"
    Log-Info "Target is shim: $isShim"
    if ($latest) { Log-Info "Latest backup: $latest" }
    Log-Info "Reset command: pwsh ./modules/shell/profile-shim.ps1 -Action reset"
}

switch ($Action) {
    "install" { Install-Shim }
    "reset" { Reset-Profile }
    "status" { Show-Status }
}
