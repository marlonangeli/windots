[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot "logging.ps1")

function Get-WindotsStateRoot {
    [CmdletBinding()]
    param()

    $base = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $HOME ".local\\share" }
    return (Join-Path $base "windots\\state")
}

function Get-WindotsStateFilePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name
    )

    $safeName = $Name.Trim().ToLowerInvariant()
    if (-not $safeName.EndsWith(".json")) {
        $safeName = "$safeName.json"
    }

    return (Join-Path (Get-WindotsStateRoot) $safeName)
}

function Write-WindotsStateFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][object]$Data
    )

    $root = Get-WindotsStateRoot
    if (-not (Test-Path $root)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }

    $path = Get-WindotsStateFilePath -Name $Name
    $Data | ConvertTo-Json -Depth 8 | Set-Content -Path $path -Encoding UTF8
    Log-Info "state written: $path"

    return $path
}
