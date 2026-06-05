[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    throw "chezmoi not found in PATH. Install it first or run scripts/bootstrap.ps1."
}

$chezmoiArgs = @("init", "--source", $repoRoot)
if ($Apply) { $chezmoiArgs += "--apply" }
if ($Force) { $chezmoiArgs += "--force" }

chezmoi @chezmoiArgs
if ($LASTEXITCODE -ne 0) {
    throw "chezmoi init failed with exit code $LASTEXITCODE"
}
