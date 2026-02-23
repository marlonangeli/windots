[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptsRoot = Join-Path $repoRoot "scripts"

. (Join-Path $scriptsRoot "common\logging.ps1")

function Add-UserPathEntry {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Entry)

    if ([string]::IsNullOrWhiteSpace($Entry)) {
        return
    }

    $currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $entries = @($currentUserPath -split ";") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($entries -contains $Entry) {
        return
    }

    $updated = if ([string]::IsNullOrWhiteSpace($currentUserPath)) {
        $Entry
    }
    else {
        "$currentUserPath;$Entry"
    }

    [Environment]::SetEnvironmentVariable("Path", $updated, "User")

    if (($env:Path -split ";") -notcontains $Entry) {
        $env:Path = "$Entry;$env:Path"
    }
}

if (Get-Command jira -ErrorAction SilentlyContinue) {
    Log-PackageStatus -Package "jira-cli" -Status "is installed" -StatusColor Green
    return
}

Log-PackageStatus -Package "jira-cli" -Status "is not installed" -StatusColor Cyan
Log-Step "[secrets] Installing jira-cli from GitHub releases"

$apiUrl = "https://api.github.com/repos/ankitpokhrel/jira-cli/releases/latest"
$apiHeaders = @{
    Accept = "application/vnd.github+json"
    "User-Agent" = "windots-installer"
}

$release = Invoke-RestMethod -Uri $apiUrl -Headers $apiHeaders -Method Get
$asset = @(
    $release.assets |
        Where-Object { $_.name -match '^jira_.*_windows_x86_64\.zip$' } |
        Select-Object -First 1
)

if (-not $asset -or -not $asset.browser_download_url) {
    throw "Could not find a Windows x86_64 jira-cli asset in latest release."
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("windots-jira-cli-" + [guid]::NewGuid().ToString("N"))
$zipPath = Join-Path $tempRoot $asset.name
$extractPath = Join-Path $tempRoot "extract"
$installDir = Join-Path $env:LOCALAPPDATA "Programs\jira-cli"
$targetExe = Join-Path $installDir "jira.exe"

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null

    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    $downloadedExe = Get-ChildItem -Path $extractPath -Filter "jira.exe" -File -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if (-not $downloadedExe) {
        throw "jira.exe was not found in downloaded archive '$($asset.name)'."
    }

    Copy-Item -Path $downloadedExe.FullName -Destination $targetExe -Force
    Add-UserPathEntry -Entry $installDir
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Test-Path $targetExe)) {
    throw "jira-cli install failed: '$targetExe' not found after installation."
}

Log-PackageStatus -Package "jira-cli" -Status "installed successfully" -StatusColor Green
