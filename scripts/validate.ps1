[CmdletBinding()]
param()

$repoRoot = Split-Path -Parent $PSScriptRoot

. (Join-Path $PSScriptRoot "common\logging.ps1")

Log-Step "Running validation..."

# TODO: existem mais arquivos para verificar, melhorar o processo de validação, talvez utilizando um arquivo de configuração para definir os arquivos e padrões a serem verificados, adicionar opções para ignorar certos arquivos ou padrões, e melhorar a saída de erros para ser mais informativa e fácil de entender.
$required = @(
    "README.md",
    ".chezmoiroot",
    "home/.chezmoi.toml.tmpl",
    "home/.chezmoiignore",
    "home/dot_gitconfig.tmpl",
    "home/dot_codex/config.toml.tmpl",
    "scripts/run-modules.ps1",
    "scripts/validate-modules.ps1",
    "scripts/windots.ps1",
    "scripts/install.ps1",
    "tests/run.ps1",
    "scripts/common/prompting.ps1",
    "scripts/modules/module-registry.ps1",
    "scripts/modules/core.ps1",
    "scripts/modules/packages.ps1",
    "scripts/modules/shell.ps1",
    "scripts/modules/themes.ps1",
    "scripts/modules/terminal.ps1",
    "scripts/modules/ai.ps1",
    "scripts/modules/mise.ps1",
    "scripts/modules/secrets.ps1",
    "scripts/modules/validate.ps1"
)

$missing = @()
foreach ($f in $required) {
    $p = Join-Path $repoRoot $f
    if (-not (Test-Path $p)) {
        $missing += $f
    }
}

if ($missing.Count -gt 0) {
    foreach ($file in $missing) {
        Log-Error "Missing required file: $file"
    }
    exit 1
}

$patterns = @(
    "ATATT",
    "x-mcp-api-key",
    "tfstoken\\s*=",
    "token\\s*:\\s*.+",
    "gh[pousr]_[A-Za-z0-9_]{20,}",
    "github_pat_[A-Za-z0-9_]{20,}",
    "sk-(proj|live|test)-[A-Za-z0-9]{20,}"
)

$targetFiles = Get-ChildItem -Path (Join-Path $repoRoot "home") -Recurse -File | Where-Object {
    $_.FullName -notmatch "node_modules|\\.git|sessions|logs|tmp"
}
$hits = $targetFiles | Select-String -Pattern $patterns
if ($hits) {
    Log-Warn "Potential secret patterns found:"
    $hits | Select-Object Path, LineNumber, Line | Format-Table -AutoSize
    exit 2
}

$moduleValidation = Join-Path $PSScriptRoot "validate-modules.ps1"
& $moduleValidation
if ($LASTEXITCODE -ne 0) {
    exit 3
}

Log-Info "Validation OK"
