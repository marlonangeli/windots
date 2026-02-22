[CmdletBinding()]
param()

function Test-WindotsMiseInstalled {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Package)

    if (Get-Command $Package.VerifyCommand -ErrorAction SilentlyContinue) {
        return $true
    }

    if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
        return $false
    }

    mise where $Package.PackageId 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Install-WindotsMisePackage {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Package)

    if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
        throw "mise not found in PATH"
    }

    mise use -g "$($Package.PackageId)@latest"
    if ($LASTEXITCODE -ne 0) {
        throw "mise install failed for '$($Package.PackageId)'"
    }
}
