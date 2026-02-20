[CmdletBinding()]
param(
    [switch]$UseSymlink
)

$ErrorActionPreference = "Stop"
$homePath = [Environment]::GetFolderPath("UserProfile")
$srcRoot = Join-Path (Split-Path -Parent $PSScriptRoot) "home\dot_config\ai"
$targets = @(
    @{ Source = Join-Path $srcRoot "mcp"; Dest = Join-Path $homePath ".config\ai\mcp" },
    @{ Source = Join-Path $srcRoot "skills"; Dest = Join-Path $homePath ".config\ai\skills" }
)

foreach ($t in $targets) {
    $destParent = Split-Path -Parent $t.Dest
    if (-not (Test-Path $destParent)) { New-Item -ItemType Directory -Path $destParent -Force | Out-Null }

    if ($UseSymlink) {
        if (Test-Path $t.Dest) { Remove-Item $t.Dest -Force -Recurse }
        New-Item -ItemType SymbolicLink -Path $t.Dest -Target $t.Source | Out-Null
    } else {
        if (Test-Path $t.Dest) { Remove-Item $t.Dest -Force -Recurse }
        Copy-Item -Path $t.Source -Destination $t.Dest -Recurse -Force
    }

    Write-Host "linked/copied: $($t.Dest)" -ForegroundColor Green
}
