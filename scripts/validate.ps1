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
    "home/dot_config/opencode/opencode.json.tmpl",
    "home/dot_config/opencode/plugins/rtk.ts",
    "home/dot_config/ai/AGENTS.md",
    "home/dot_config/ai/skills/manifest.toml",
    "home/dot_config/ai/skills/pr-workflow/SKILL.md",
    "home/dot_config/ai/skills/pipeline-triage/SKILL.md",
    "home/dot_config/ai/skills/jira-worklog/SKILL.md",
    "home/dot_config/ai/mcp/servers.toml.tmpl",
    "home/dot_config/jira/.config.yml.tmpl",
    "install.ps1",
    "scripts/bootstrap.ps1",
    "scripts/ilegna.ps1",
    "scripts/doctor.ps1",
    "scripts/config-backup.ps1",
    "scripts/link.ps1",
    "scripts/ai-sync.ps1",
    "scripts/git-worktree.ps1",
    "scripts/pr.ps1",
    "scripts/pipeline.ps1",
    "scripts/jira-time.ps1",
    "scripts/wsl-bootstrap-arch.sh",
    "scripts/run-modules.ps1",
    "scripts/windots.ps1",
    "scripts/lint.ps1",
    "scripts/format.ps1",
    "scripts/format-stdin.ps1",
    "scripts/psscriptanalyzer.psd1",
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
    "modules/secrets/install-jira-cli.ps1",
    "modules/validate/module.ps1",
    "home/dot_config/powershell/Microsoft.PowerShell_profile.ps1",
    "home/dot_config/powershell/powershell.config.json",
    "home/dot_config/powershell/profile.d/00-core.ps1",
    "home/dot_config/powershell/profile.d/10-env.ps1",
    "home/dot_config/powershell/profile.d/20-path.ps1",
    "home/dot_config/powershell/profile.d/30-prompt.ps1",
    "home/dot_config/powershell/profile.d/40-aliases.ps1",
    "home/dot_config/powershell/profile.d/50-git.ps1",
    "home/dot_config/powershell/profile.d/60-dev.ps1",
    "home/dot_config/powershell/profile.d/70-ai.ps1",
    "home/dot_config/powershell/profile.d/80-ilegna.ps1",
    "home/dot_config/starship.toml",
    "home/AppData/Roaming/Zellij/config/config.kdl",
    "home/AppData/Roaming/Zellij/config/layouts/dev.kdl",
    "home/AppData/Roaming/Zellij/config/layouts/oc.kdl",
    "home/AppData/Roaming/Zellij/config/layouts/grid.kdl",
    "home/dot_wslconfig",
    "tests/run.ps1",
    "tests/smoke.ps1",
    "tests/pester/ilegna-command.Tests.ps1",
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
