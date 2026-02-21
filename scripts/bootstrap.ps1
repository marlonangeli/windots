[CmdletBinding()]
param(
    [ValidateSet("full","clean")]
    [string]$Mode = "full",
    [switch]$SkipInstall,
    [switch]$SkipMise
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "common\logging.ps1")

Log-Step "Applying chezmoi changes..."
if (Get-Command chezmoi -ErrorAction SilentlyContinue) {
    chezmoi apply
} else {
    Log-Warn "chezmoi not found. Install it first."
}

if (-not $SkipInstall) {
    & "$PSScriptRoot\install-tools.ps1" -Mode $Mode
}

Log-Step "Linking AI config..."
& "$PSScriptRoot\link-ai-configs.ps1"

Log-Step "Installing PowerShell profile shim..."
& "$PSScriptRoot\install-profile-shim.ps1"

Log-Step "Configuring oh-my-posh themes and fonts..."
& "$PSScriptRoot\setup-oh-my-posh.ps1"

if (-not $SkipMise -and (Get-Command mise -ErrorAction SilentlyContinue)) {
    Log-Step "Configuring mise PATH and activation..."
    & "$PSScriptRoot\setup-mise.ps1"

    $miseConfig = Join-Path $HOME ".config\mise\config.toml"
    if (Test-Path $miseConfig) {
        Log-Step "Installing mise toolchain..."
        mise install
        if ($LASTEXITCODE -ne 0) { throw "mise install failed" }
        mise doctor
        if ($LASTEXITCODE -ne 0) { Log-Warn "mise doctor reported issues. Review output above." }
        mise ls
    } else {
        Log-Warn "mise config not found: $miseConfig"
    }
}

Log-Info "Bootstrap complete."
