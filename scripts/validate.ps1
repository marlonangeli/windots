[CmdletBinding()]
param()

$repoRoot = Split-Path -Parent $PSScriptRoot

. (Join-Path $PSScriptRoot "common\logging.ps1")

Log-Step "Running validation..."

# 1) Basic files
$required = @(
    "README.md",
    ".chezmoiroot",
    "home/.chezmoi.toml.tmpl",
    "home/.chezmoiignore",
    "home/dot_gitconfig.tmpl",
    "home/dot_codex/config.toml.tmpl"
)
foreach ($f in $required) {
    $p = Join-Path $repoRoot $f
    if (-not (Test-Path $p)) {
        Log-Error "Missing required file: $f"
        exit 1
    }
}

# 2) Secret patterns
$patterns = @("ATATT","x-mcp-api-key","tfstoken\\s*=","token\\s*:\\s*.+")
$targetFiles = Get-ChildItem -Path (Join-Path $repoRoot "home") -Recurse -File | Where-Object {
    $_.FullName -notmatch "node_modules|\\.git|sessions|logs|tmp"
}
$hits = $targetFiles | Select-String -Pattern $patterns
if ($hits) {
    Log-Warn "Potential secret patterns found:"
    $hits | Select-Object Path,LineNumber,Line | Format-Table -AutoSize
    exit 2
}

Log-Info "Validation OK"
