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

$starshipCommand = Get-Command starship -ErrorAction SilentlyContinue
if (-not $starshipCommand -and (Get-Command mise -ErrorAction SilentlyContinue)) {
    $starshipPath = mise which starship 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($starshipPath) -and (Test-Path $starshipPath.Trim())) {
        $starshipCommand = [pscustomobject]@{ Source = $starshipPath.Trim() }
    }
}

if ($starshipCommand) {
    $cacheRoot = Join-Path $HOME ".cache\windots"
    $cachePath = Join-Path $cacheRoot "starship-init.ps1"
    if (-not (Test-Path $cacheRoot)) { New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null }

    & $starshipCommand.Source init powershell --print-full-init | Set-Content -Path $cachePath -Encoding UTF8
    Log-Info "Starship ready: $starshipConfig"
    Log-Info "Starship init cache: $cachePath"
}
else {
    Log-Warn "Starship is not in PATH yet. It is installed by mise when enabled."
}
