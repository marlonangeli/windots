[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

. (Join-Path $PSScriptRoot "common\logging.ps1")
. (Join-Path $repoRoot "modules\module-registry.ps1")
. (Join-Path $repoRoot "modules\packages\manager.ps1")

Log-Step "Running validation"

$requiredFiles = @(
    "README.md",
    "docs/RESTORE.md",
    ".chezmoiroot",
    "home/.chezmoi.toml.tmpl",
    "home/.chezmoiignore",
    "home/dot_gitconfig.tmpl",
    "home/dot_codex/config.toml.tmpl",
    "install.ps1",
    "scripts/bootstrap.ps1",
    "scripts/run-modules.ps1",
    "scripts/windots.ps1",
    "scripts/validate.ps1",
    "scripts/validate-modules.ps1",
    "scripts/common/logging.ps1",
    "scripts/common/guardrails.ps1",
    "scripts/common/preflight.ps1",
    "scripts/common/state.ps1",
    "scripts/common/winget.ps1",
    "modules/module-registry.ps1",
    "modules/core/module.ps1",
    "modules/packages/module.ps1",
    "modules/packages/repository.psd1",
    "modules/packages/manager.ps1",
    "modules/packages/provider-winget.ps1",
    "modules/packages/provider-mise.ps1",
    "modules/shell/module.ps1",
    "modules/shell/profile-shim.ps1",
    "modules/development/module.ps1",
    "modules/themes/module.ps1",
    "modules/themes/setup.ps1",
    "modules/terminal/module.ps1",
    "modules/ai/module.ps1",
    "modules/ai/link-configs.ps1",
    "modules/mise/module.ps1",
    "modules/mise/setup.ps1",
    "modules/secrets/module.ps1",
    "modules/secrets/migrate.ps1",
    "modules/secrets/deps-check.ps1",
    "modules/validate/module.ps1",
    "tests/run.ps1",
    "tests/smoke.ps1",
    "tests/pester/windots-command.Tests.ps1"
)

$missingFiles = @()
foreach ($relativePath in $requiredFiles) {
    $fullPath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path $fullPath)) {
        $missingFiles += $relativePath
    }
}

if ($missingFiles.Count -gt 0) {
    foreach ($file in $missingFiles) {
        Log-Error "Missing required file: $file"
    }
    exit 1
}

$packageManifest = Test-WindotsPackageManifest -Path (Join-Path $repoRoot "modules\packages\repository.psd1")
if (-not $packageManifest.IsValid) {
    foreach ($errorMessage in $packageManifest.Errors) {
        Log-Error $errorMessage
    }
    exit 2
}

$moduleValidation = Test-WindotsModuleRegistry -ScriptsRoot $repoRoot
if (-not $moduleValidation.IsValid) {
    foreach ($moduleError in $moduleValidation.Errors) {
        Log-Error $moduleError
    }
    exit 3
}

$patterns = @(
    'ATATT',
    'x-mcp-api-key',
    'tfstoken\s*=',
    'token\s*:\s*"(?!")[^"]+"',
    'gh[pousr]_[A-Za-z0-9_]{20,}',
    'github_pat_[A-Za-z0-9_]{20,}',
    'sk-(proj|live|test)-[A-Za-z0-9]{20,}'
)

$scanRoots = @(
    (Join-Path $repoRoot "home"),
    (Join-Path $repoRoot "scripts"),
    (Join-Path $repoRoot "modules")
)

$targetFiles = foreach ($scanRoot in $scanRoots) {
    if (Test-Path $scanRoot) {
        Get-ChildItem -Path $scanRoot -Recurse -File | Where-Object {
            $_.FullName -notmatch "node_modules|\\.git|sessions|logs|tmp" -and
            $_.FullName -notmatch "scripts[\\/]validate\.ps1$"
        }
    }
}

$hits = $targetFiles | Select-String -Pattern $patterns
if ($hits) {
    Log-Warn "Potential secret patterns found:"
    $hits | Select-Object Path, LineNumber, Line | Format-Table -AutoSize
    exit 4
}

Log-Info "Validation OK"
