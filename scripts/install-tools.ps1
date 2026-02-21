[CmdletBinding()]
param(
    [ValidateSet("full","clean")]
    [string]$Mode = "full"
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common\logging.ps1")

function Install-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [switch]$Optional
    )

    $installed = winget list --id $Id --exact --accept-source-agreements 2>$null
    if ($LASTEXITCODE -eq 0 -and $installed) {
        Log-Info "already installed: $Id"
        return
    }

    Log-Step "installing: $Id"
    winget install --id $Id --exact --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        if ($Optional) {
            Log-Warn "optional package failed: $Id"
            return
        }
        throw "failed to install package: $Id"
    }
}

$packages = @(
    "Microsoft.PowerShell",
    "Microsoft.WindowsTerminal",
    "Git.Git",
    "Microsoft.AzureCLI",
    "jdx.mise"
)

if ($Mode -eq "full") {
    $packages += @(
        "Docker.DockerDesktop",
        "Microsoft.VisualStudioCode",
        "ZedIndustries.Zed",
        "DEVCOM.JetBrainsMonoNerdFont",
        "GitHub.Copilot"
    )
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found"
}

foreach ($id in $packages) {
    $optional = $id -in @("DEVCOM.JetBrainsMonoNerdFont", "GitHub.Copilot")
    Install-WingetPackage -Id $id -Optional:$optional
}
