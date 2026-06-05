[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$scriptsRoot = Join-Path $repoRoot "scripts"
. (Join-Path $scriptsRoot "common\logging.ps1")

$starshipConfig = Join-Path $HOME ".config\starship.toml"
if (-not (Test-Path $starshipConfig)) {
    Log-Warn "Starship config not found yet: $starshipConfig"
    Log-Warn "Run 'chezmoi apply' to materialize it."
    return
}

if (Get-Command starship -ErrorAction SilentlyContinue) {
    Log-Info "Starship ready: $starshipConfig"
}
else {
    Log-Warn "Starship is not in PATH yet. It is installed by mise when enabled."
}
