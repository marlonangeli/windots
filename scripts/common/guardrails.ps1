[CmdletBinding()]
param()

function Assert-WindotsRequiredCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$Optional
    )

    if (Get-Command $Name -ErrorAction SilentlyContinue) {
        return $true
    }

    if ($Optional) {
        return $false
    }

    throw "Required command not found: $Name"
}
