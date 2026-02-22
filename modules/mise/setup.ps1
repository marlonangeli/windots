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

try {
    mise activate pwsh | Out-String | Invoke-Expression
}
catch {
    Log-Warn "mise activate pwsh failed in this session."
}
