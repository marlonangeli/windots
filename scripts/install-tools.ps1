[CmdletBinding()]
param(
    [ValidateSet("full","clean")]
    [string]$Mode = "full"
)

$packages = @(
    "Microsoft.PowerShell",
    "Microsoft.WindowsTerminal",
    "Git.Git",
    "Microsoft.AzureCLI",
    "JanDeDobbeleer.OhMyPosh",
    "ajeetdsouza.zoxide",
    "jdx.mise"
)

if ($Mode -eq "full") {
    $packages += @(
        "Docker.DockerDesktop",
        "Microsoft.VisualStudioCode",
        "ZedIndustries.Zed",
        "JetBrains.JetBrainsMonoNerdFont"
    )
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found"
}

foreach ($id in $packages) {
    $installed = winget list --id $id --exact --accept-source-agreements 2>$null
    if ($LASTEXITCODE -eq 0 -and $installed) {
        Write-Host "already installed: $id" -ForegroundColor DarkGray
        continue
    }
    Write-Host "installing: $id" -ForegroundColor Cyan
    winget install --id $id --exact --accept-source-agreements --accept-package-agreements
}

if (Get-Command mise -ErrorAction SilentlyContinue) {
    Write-Host "mise detected. Configure globally as needed:" -ForegroundColor Yellow
    Write-Host "  mise use -g node@lts pnpm@latest bun@latest" -ForegroundColor Yellow
}
