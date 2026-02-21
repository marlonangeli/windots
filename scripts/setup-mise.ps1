[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
    Write-Warning "mise not found."
    exit 0
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
    Write-Host "Added mise shims to user PATH: $shimsPath" -ForegroundColor Green
}
elseif ($userPath -notlike "*$shimsPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$shimsPath", "User")
    Write-Host "Updated user PATH with mise shims: $shimsPath" -ForegroundColor Green
}
else {
    Write-Host "mise shims already present in user PATH." -ForegroundColor DarkGray
}

try {
    mise activate pwsh | Out-String | Invoke-Expression
}
catch {
    Write-Verbose "mise activate failed in this session: $_"
}
