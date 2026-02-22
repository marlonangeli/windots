[CmdletBinding()]
param(
    [switch]$UseSymlink
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptsRoot = Join-Path $repoRoot "scripts"
. (Join-Path $scriptsRoot "common\logging.ps1")

$homePath = [Environment]::GetFolderPath("UserProfile")
$srcRoot = Join-Path $repoRoot "home\dot_config\ai"
$targets = @(
    @{ Source = Join-Path $srcRoot "mcp"; Dest = Join-Path $homePath ".config\ai\mcp" },
    @{ Source = Join-Path $srcRoot "skills"; Dest = Join-Path $homePath ".config\ai\skills" }
)

foreach ($target in $targets) {
    if (-not (Test-Path $target.Source)) {
        throw "Missing AI source folder: $($target.Source)"
    }

    $destParent = Split-Path -Parent $target.Dest
    if (-not (Test-Path $destParent)) {
        New-Item -ItemType Directory -Path $destParent -Force | Out-Null
    }

    if (Test-Path $target.Dest) {
        Remove-Item $target.Dest -Force -Recurse
    }

    if ($UseSymlink) {
        New-Item -ItemType SymbolicLink -Path $target.Dest -Target $target.Source | Out-Null
        Log-Info "symlink created: $($target.Dest) -> $($target.Source)"
    }
    else {
        Copy-Item -Path $target.Source -Destination $target.Dest -Recurse -Force
        Log-Info "folder copied: $($target.Source) -> $($target.Dest)"
    }
}
