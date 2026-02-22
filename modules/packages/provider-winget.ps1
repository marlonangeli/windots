[CmdletBinding()]
param()

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $repoRoot "scripts\common\winget.ps1")

function Test-WindotsWingetInstalled {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Package)

    return (Test-WingetPackageInstalled -Id $Package.PackageId)
}

function Install-WindotsWingetPackage {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Package)

    try {
        Invoke-WingetInstall -Id $Package.PackageId
    }
    catch {
        throw "winget package installation failed for '$($Package.PackageId)': $($_.Exception.Message)"
    }
}
