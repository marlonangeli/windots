[CmdletBinding()]
param(
    [string]$Output = "./_staging"
)

$homePath = [Environment]::GetFolderPath("UserProfile")
$map = @(
    @{ Source = "$homePath\.gitconfig"; Dest = "home/dot_gitconfig.tmpl" },
    @{ Source = "$homePath\.gitignore_global"; Dest = "home/dot_gitignore_global" },
    @{ Source = "$homePath\.codex\config.toml"; Dest = "home/dot_codex/config.toml.tmpl" },
    @{ Source = "$homePath\AppData\Roaming\Zed\settings.json"; Dest = "home/AppData/Roaming/Zed/settings.json.tmpl" }
)

foreach ($item in $map) {
    if (Test-Path $item.Source) {
        $dest = Join-Path $Output $item.Dest
        $dir = Split-Path -Parent $dest
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Copy-Item $item.Source $dest -Force
        Write-Host "exported: $($item.Source) -> $dest" -ForegroundColor Green
    }
}
