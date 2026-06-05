[CmdletBinding()]
param(
    [ValidateSet("backup", "list", "restore")]
    [string]$Action = "backup",

    [string]$Version,

    [string[]]$Items = @("all"),

    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Get-ConfigBackupRoot {
    [CmdletBinding()]
    param()

    $base = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $HOME ".local\share" }
    $root = Join-Path $base "windots\backups\configs"
    if (-not (Test-Path $root)) { New-Item -ItemType Directory -Path $root -Force | Out-Null }
    return $root
}

function Get-BackupCatalog {
    [CmdletBinding()]
    param()

    @(
        [pscustomobject]@{ Name = "gitconfig"; Group = "git"; Source = Join-Path $HOME ".gitconfig"; BackupPath = "git/.gitconfig" },
        [pscustomobject]@{ Name = "gitconfig-local"; Group = "git"; Source = Join-Path $HOME ".gitconfig.local"; BackupPath = "git/.gitconfig.local" },
        [pscustomobject]@{ Name = "gitignore-global"; Group = "git"; Source = Join-Path $HOME ".gitignore_global"; BackupPath = "git/.gitignore_global" },
        [pscustomobject]@{ Name = "ssh-config"; Group = "ssh"; Source = Join-Path $HOME ".ssh\config"; BackupPath = "ssh/config" },
        [pscustomobject]@{ Name = "ssh-known-hosts"; Group = "ssh"; Source = Join-Path $HOME ".ssh\known_hosts"; BackupPath = "ssh/known_hosts" },
        [pscustomobject]@{ Name = "ssh-config-dir"; Group = "ssh"; Source = Join-Path $HOME ".ssh\config.d"; BackupPath = "ssh/config.d" }
    )
}

function Resolve-BackupItems {
    [CmdletBinding()]
    param([string[]]$SelectedItems)

    $catalog = Get-BackupCatalog
    $requested = @(
        $SelectedItems |
            ForEach-Object { $_ -split "," } |
            ForEach-Object { $_.Trim().ToLowerInvariant() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )

    if (-not $requested -or $requested.Count -eq 0 -or $requested -contains "all") {
        return $catalog
    }

    $resolved = @()
    foreach ($item in $requested) {
        $matches = @($catalog | Where-Object { $_.Name -eq $item -or $_.Group -eq $item })
        if (-not $matches -or $matches.Count -eq 0) {
            throw "Unknown backup item '$item'. Use: all, git, ssh, gitconfig, gitconfig-local, gitignore-global, ssh-config, ssh-known-hosts, ssh-config-dir."
        }
        $resolved += $matches
    }

    return @($resolved | Sort-Object Name -Unique)
}

function Get-BackupVersions {
    [CmdletBinding()]
    param()

    $root = Get-ConfigBackupRoot
    @(
        Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName "manifest.json") } |
            Sort-Object Name -Descending
    )
}

function Read-BackupManifest {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$VersionPath)

    Get-Content -Path (Join-Path $VersionPath "manifest.json") -Raw | ConvertFrom-Json
}

function Show-BackupVersions {
    [CmdletBinding()]
    param()

    $versions = Get-BackupVersions
    if (-not $versions -or $versions.Count -eq 0) {
        Write-Host "No config backups found." -ForegroundColor Yellow
        return @()
    }

    for ($i = 0; $i -lt $versions.Count; $i++) {
        $manifest = Read-BackupManifest -VersionPath $versions[$i].FullName
        $items = @($manifest.items | ForEach-Object { $_.name }) -join ", "
        Write-Host ("{0}. {1}  {2}  [{3}]" -f ($i + 1), $versions[$i].Name, $manifest.createdAt, $items)
    }

    return $versions
}

function Resolve-BackupVersionPath {
    [CmdletBinding()]
    param([string]$RequestedVersion)

    $versions = Get-BackupVersions
    if (-not $versions -or $versions.Count -eq 0) { throw "No config backups found." }

    if ([string]::IsNullOrWhiteSpace($RequestedVersion)) {
        Show-BackupVersions | Out-Null
        $choice = Read-Host "Select backup number or version"
        if ([string]::IsNullOrWhiteSpace($choice)) { throw "Restore canceled: no version selected." }
        $RequestedVersion = $choice.Trim()
    }

    if ($RequestedVersion -eq "latest") { return $versions[0].FullName }

    if ($RequestedVersion -match '^\d+$') {
        $index = [int]$RequestedVersion - 1
        if ($index -ge 0 -and $index -lt $versions.Count) { return $versions[$index].FullName }
    }

    $matches = @($versions | Where-Object { $_.Name -eq $RequestedVersion -or $_.Name.StartsWith($RequestedVersion) })
    if ($matches.Count -eq 1) { return $matches[0].FullName }
    if ($matches.Count -gt 1) { throw "Version '$RequestedVersion' matches more than one backup. Use the full version." }

    throw "Backup version not found: $RequestedVersion"
}

function Copy-BackupItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )

    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

function Invoke-ConfigBackup {
    [CmdletBinding()]
    param([string[]]$SelectedItems)

    $root = Get-ConfigBackupRoot
    $version = Get-Date -Format "yyyyMMdd-HHmmss"
    $versionRoot = Join-Path $root $version
    $filesRoot = Join-Path $versionRoot "files"
    New-Item -ItemType Directory -Path $filesRoot -Force | Out-Null

    $backedUp = @()
    foreach ($item in Resolve-BackupItems -SelectedItems $SelectedItems) {
        if (-not (Test-Path $item.Source)) { continue }

        $backupPath = Join-Path $filesRoot $item.BackupPath
        Copy-BackupItem -Source $item.Source -Destination $backupPath
        $fileInfo = Get-Item -LiteralPath $item.Source
        $backedUp += [pscustomobject]@{
            name = $item.Name
            group = $item.Group
            source = $item.Source
            backupPath = Join-Path "files" $item.BackupPath
            type = if ($fileInfo.PSIsContainer) { "directory" } else { "file" }
        }
    }

    if ($backedUp.Count -eq 0) {
        Remove-Item -LiteralPath $versionRoot -Recurse -Force
        throw "No selected config files exist to back up."
    }

    $manifest = [pscustomobject]@{
        version = $version
        createdAt = (Get-Date).ToString("o")
        computerName = $env:COMPUTERNAME
        userName = [Environment]::UserName
        root = $versionRoot
        items = @($backedUp)
    }

    $manifest | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $versionRoot "manifest.json") -Encoding UTF8
    Write-Host "Config backup created: $version" -ForegroundColor Green
    Write-Host $versionRoot -ForegroundColor DarkGray
}

function Save-PreRestoreCopy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$PreRestoreRoot
    )

    if (-not (Test-Path $Path)) { return }
    $destination = Join-Path $PreRestoreRoot $RelativePath
    Copy-BackupItem -Source $Path -Destination $destination
}

function Invoke-ConfigRestore {
    [CmdletBinding()]
    param(
        [string]$RequestedVersion,
        [string[]]$SelectedItems,
        [switch]$ForceRestore
    )

    $versionPath = Resolve-BackupVersionPath -RequestedVersion $RequestedVersion
    $manifest = Read-BackupManifest -VersionPath $versionPath
    $selected = Resolve-BackupItems -SelectedItems $SelectedItems
    $selectedNames = @($selected | ForEach-Object { $_.Name })
    $itemsToRestore = @($manifest.items | Where-Object { $selectedNames -contains $_.name })

    if (-not $itemsToRestore -or $itemsToRestore.Count -eq 0) {
        throw "Backup '$($manifest.version)' has no matching items to restore."
    }

    $preRestoreRoot = Join-Path (Get-ConfigBackupRoot) ("pre-restore-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    $preRestoreUsed = $false

    foreach ($item in $itemsToRestore) {
        $source = Join-Path $versionPath $item.backupPath
        $destination = $item.source
        if (-not (Test-Path $source)) {
            Write-Warning "Backup item missing: $source"
            continue
        }

        if (Test-Path $destination) {
            $shouldOverwrite = [bool]$ForceRestore
            if (-not $shouldOverwrite) {
                $answer = Read-Host "Overwrite existing '$destination'? (y/N)"
                $shouldOverwrite = $answer -in @("y", "Y", "yes", "YES")
            }

            if (-not $shouldOverwrite) {
                Write-Host "Skipped: $destination" -ForegroundColor Yellow
                continue
            }

            Save-PreRestoreCopy -Path $destination -RelativePath $item.backupPath -PreRestoreRoot $preRestoreRoot
            $preRestoreUsed = $true
            Remove-Item -LiteralPath $destination -Recurse -Force
        }

        Copy-BackupItem -Source $source -Destination $destination
        Write-Host "Restored: $destination" -ForegroundColor Green
    }

    if ($preRestoreUsed) {
        Write-Host "Previous files were saved before restore:" -ForegroundColor Yellow
        Write-Host $preRestoreRoot -ForegroundColor DarkGray
    }
}

switch ($Action) {
    "backup" { Invoke-ConfigBackup -SelectedItems $Items }
    "list" { Show-BackupVersions | Out-Null }
    "restore" { Invoke-ConfigRestore -RequestedVersion $Version -SelectedItems $Items -ForceRestore:$Force }
}
