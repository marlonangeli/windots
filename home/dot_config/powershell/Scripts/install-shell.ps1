[CmdletBinding()]
param(
    [ValidateSet("all","core","terminal","git","docker","azure","editors","node","dotnet","shell","ai")]
    [string[]]$Components = @("all"),
    [switch]$Minimal,
    [switch]$IncludeFont,
    [switch]$SkipOptional,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Invoke-Safe {
    param([scriptblock]$Action, [string]$Description)
    try {
        & $Action
    }
    catch {
        Write-Warning "$Description failed: $($_.Exception.Message)"
    }
}

function Install-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$CommandName
    )

    if (Test-WingetInstalled -Id $Id) {
        Write-Host "  - already installed: $Id" -ForegroundColor DarkGray
        return
    }

    $cmd = "winget install --id $Id --exact --accept-source-agreements --accept-package-agreements"
    if ($DryRun) {
        Write-Host "  - [dry-run] $cmd" -ForegroundColor Yellow
        return
    }

    Invoke-Safe -Description "winget install $Id" -Action { Invoke-Expression $cmd }
}

function Install-DotnetTool {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$CommandName = $Name
    )

    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        Write-Warning "dotnet not found; skipping tool installation for $Name"
        return
    }

    if (Test-DotnetToolInstalled -Name $Name) {
        Write-Host "  - already installed: dotnet tool $Name" -ForegroundColor DarkGray
        return
    }

    $cmd = "dotnet tool install --global $Name"
    if ($DryRun) {
        Write-Host "  - [dry-run] $cmd" -ForegroundColor Yellow
        return
    }

    Invoke-Safe -Description "dotnet tool install $Name" -Action { Invoke-Expression $cmd }
}

function Ensure-Corepack {
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Warning "node not found; skipping corepack setup"
        return
    }

    if ($DryRun) {
        Write-Host "  - [dry-run] corepack enable; corepack prepare pnpm@latest --activate; corepack prepare yarn@stable --activate" -ForegroundColor Yellow
        return
    }

    Invoke-Safe -Description "corepack enable" -Action { corepack enable }
    Invoke-Safe -Description "corepack pnpm" -Action { corepack prepare pnpm@latest --activate }
    Invoke-Safe -Description "corepack yarn" -Action { corepack prepare yarn@stable --activate }
}

function Test-WingetInstalled {
    param([Parameter(Mandatory)][string]$Id)
    $result = winget list --id $Id --exact --accept-source-agreements 2>$null
    return $LASTEXITCODE -eq 0 -and $result
}

function Test-DotnetToolInstalled {
    param([Parameter(Mandatory)][string]$Name)
    $list = dotnet tool list -g 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $list) { return $false }
    return $list -match "(?m)^\s*$([regex]::Escape($Name))\s+"
}

function Should-InstallGroup {
    param([string]$Group)
    if ($Components -contains "all") { return $true }
    if ($Components -contains "core" -and $Group -in @("terminal","git","docker","azure","editors","node","dotnet","shell","ai")) { return $true }
    return $Components -contains $Group
}

Write-Step "Checking package manager"
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found. Install App Installer: https://apps.microsoft.com/detail/9NBLGGH4NNS1"
}

$required = @(
    @{ Id = "Microsoft.PowerShell"; Group = "terminal" },
    @{ Id = "Microsoft.WindowsTerminal"; Group = "terminal" },
    @{ Id = "Git.Git"; Group = "git" },
    @{ Id = "Microsoft.AzureCLI"; Group = "azure" },
    @{ Id = "Docker.DockerDesktop"; Group = "docker" },
    @{ Id = "Microsoft.VisualStudioCode"; Group = "editors" },
    @{ Id = "ZedIndustries.Zed"; Group = "editors" },
    @{ Id = "JanDeDobbeleer.OhMyPosh"; Group = "shell" },
    @{ Id = "ajeetdsouza.zoxide"; Group = "shell" },
    @{ Id = "OpenJS.NodeJS.LTS"; Group = "node" }
)

$optional = @(
    @{ Id = "jdx.mise"; Command = "mise" },
    @{ Id = "Oven-sh.Bun"; Command = "bun" },
    @{ Id = "Yarn.Yarn"; Command = "yarn" },
    @{ Id = "pnpm.pnpm"; Command = "pnpm" },
    @{ Id = "DEVCOM.JetBrainsMonoNerdFont"; Command = $null }
)

Write-Step "Installing core tooling"
foreach ($pkg in $required) {
    if (Should-InstallGroup -Group $pkg.Group) {
        Install-WingetPackage -Id $pkg.Id
    }
}

if (-not $Minimal -and -not $SkipOptional) {
    Write-Step "Installing optional tooling"
    foreach ($pkg in $optional) {
        if (-not $IncludeFont -and $pkg.Id -like "*NerdFont*") { continue }
        if ($pkg.Command -eq "mise" -and -not (Should-InstallGroup -Group "node")) { continue }
        Install-WingetPackage -Id $pkg.Id -CommandName $pkg.Command
    }
}

if (Should-InstallGroup -Group "dotnet" -and (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Step "Installing dotnet tools"
    Install-DotnetTool -Name "dotnet-ef" -CommandName "dotnet-ef"
    Install-WingetPackage -Id "Microsoft.Aspire" -CommandName "aspire"
    Install-DotnetTool -Name "aspire.cli" -CommandName "aspire"
}

if (Should-InstallGroup -Group "node") {
    Write-Step "Node package managers (corepack)"
    Ensure-Corepack
}

if (Should-InstallGroup -Group "ai") {
    Write-Step "Jira CLI fallback"
    if (-not (Get-Command jira -ErrorAction SilentlyContinue)) {
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            if ($DryRun) {
                Write-Host "  - [dry-run] npm i -g jira-cli" -ForegroundColor Yellow
            }
            else {
                Invoke-Safe -Description "npm i -g jira-cli" -Action { npm i -g jira-cli }
            }
        }
        else {
            Write-Warning "jira CLI not installed (npm unavailable)."
        }
    }
}

Write-Step "Done"
Write-Host "Next: open a new terminal and run 'pmode' / 'pclean' / 'pfull'." -ForegroundColor Green
