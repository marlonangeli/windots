[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptsRoot = Join-Path $repoRoot "scripts"
. (Join-Path $scriptsRoot "common\logging.ps1")

if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
    Log-Warn "mise not found in PATH."
    return
}

$shimsPath = Join-Path $env:LOCALAPPDATA "mise\shims"
if (-not (Test-Path $shimsPath)) {
    New-Item -ItemType Directory -Path $shimsPath -Force | Out-Null
}

if ($env:PATH -notlike "*$shimsPath*") {
    $env:PATH = "$shimsPath;$env:PATH"
}

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ([string]::IsNullOrWhiteSpace($userPath)) {
    [Environment]::SetEnvironmentVariable("Path", $shimsPath, "User")
    Log-Info "Added mise shims to user PATH."
}
elseif ($userPath -notlike "*$shimsPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$shimsPath", "User")
    Log-Info "Updated user PATH with mise shims."
}
else {
    Log-Info "mise shims already present in user PATH."
}

$env:MISE_NOT_FOUND_AUTO_INSTALL = "0"
Log-Info "mise configured for shims/PATH. Set MISE_ACTIVATE=1 before pwsh to opt into prompt-time activation."
