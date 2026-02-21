[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Repo,

    [ValidateSet("full", "clean")]
    [string]$Mode = "full",

    [switch]$SkipBaseInstall,
    [switch]$UseSymlinkAI,
    [switch]$SkipSecretsChecks,
    [string]$LogPath,
    [switch]$AutoApply,
    [switch]$NoPrompt
)

$ErrorActionPreference = "Stop"
$script:CurrentStep = "bootstrap"
$script:chezmoiExe = $null
$startedTranscript = $false

function Write-Step {
    param([string]$Message)
    $script:CurrentStep = $Message
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Ensure-WingetPackage {
    param([Parameter(Mandatory)][string]$Id)

    $installed = winget list --id $Id --exact --accept-source-agreements 2>$null
    if ($LASTEXITCODE -eq 0 -and $installed) {
        Write-Host "    already installed: $Id" -ForegroundColor DarkGray
        return
    }

    Write-Host "    installing: $Id" -ForegroundColor Yellow
    winget install --id $Id --exact --accept-source-agreements --accept-package-agreements
}

function Refresh-ProcessPath {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [Environment]::GetEnvironmentVariable("Path", "User")
    $combined = @($machine, $user) -join ";"
    if (-not [string]::IsNullOrWhiteSpace($combined)) {
        $env:Path = $combined
    }
}

function Resolve-Chezmoi {
    $cmd = Get-Command chezmoi -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    Refresh-ProcessPath
    $cmd = Get-Command chezmoi -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidateRoots = @(
        "$env:LOCALAPPDATA\Microsoft\WinGet\Packages",
        "$env:LOCALAPPDATA\Programs"
    ) | Where-Object { Test-Path $_ }

    foreach ($root in $candidateRoots) {
        $hit = Get-ChildItem -Path $root -Filter "chezmoi.exe" -File -Recurse -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }

    return $null
}

function Invoke-Step {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Action
    )

    Write-Step $Name
    & $Action
}

function Prompt-OrDefault {
    param(
        [Parameter(Mandatory)][string]$Label,
        [string]$Default = ""
    )

    if ($NoPrompt) { return $Default }

    $suffix = if ([string]::IsNullOrWhiteSpace($Default)) { "" } else { " [$Default]" }
    $value = Read-Host "$Label$suffix"
    if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
    return $value
}

function Set-InstallerEnvData {
    $defaultName = ""
    $defaultEmail = ""
    $defaultGithub = ""

    try { $defaultName = (git config --global user.name 2>$null) } catch {}
    try { $defaultEmail = (git config --global user.email 2>$null) } catch {}
    if ($defaultEmail -and $defaultEmail -match "@") {
        $defaultGithub = ($defaultEmail -split "@")[0]
    }

    Write-Step "Collecting setup data"
    $name = Prompt-OrDefault -Label "Git user.name" -Default $defaultName
    $email = Prompt-OrDefault -Label "Git user.email" -Default $defaultEmail
    $github = Prompt-OrDefault -Label "GitHub username" -Default $defaultGithub
    $azureOrg = Prompt-OrDefault -Label "Azure DevOps organization URL (optional)" -Default ""
    $azureProject = Prompt-OrDefault -Label "Azure DevOps project (optional)" -Default ""

    $env:CHEZMOI_NAME = $name
    $env:CHEZMOI_EMAIL = $email
    $env:CHEZMOI_GITHUB_USERNAME = $github
    $env:CHEZMOI_AZURE_ORG = $azureOrg
    $env:CHEZMOI_AZURE_PROJECT = $azureProject
}

function Get-RepoRemotePattern {
    param([Parameter(Mandatory)][string]$RepoName)
    return "(github\.com[:/]" + [regex]::Escape($RepoName) + "(\.git)?$)"
}

function Resolve-ExistingSource {
    param(
        [Parameter(Mandatory)][string]$Chez,
        [Parameter(Mandatory)][string]$RepoName
    )

    $sourcePath = & $Chez source-path 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $sourcePath -or -not (Test-Path $sourcePath)) {
        return $null
    }

    $remote = & $Chez git remote get-url origin 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    $pattern = Get-RepoRemotePattern -RepoName $RepoName
    if ($remote -match $pattern) {
        Write-Host "    existing chezmoi source detected and matches repo: $remote" -ForegroundColor DarkGray
        return $sourcePath
    }

    throw "Existing chezmoi source points to a different remote: $remote"
}

function Resolve-RepoScriptPath {
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$RelativePath
    )

    $sourceParent = Split-Path -Parent $SourcePath
    $candidates = @(
        (Join-Path $SourcePath $RelativePath),
        (Join-Path (Join-Path $SourcePath "home") $RelativePath),
        (Join-Path $sourceParent $RelativePath)
    )

    return $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}

if (-not $LogPath) {
    $LogPath = Join-Path $env:TEMP ("windots-install-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
}

try {
    Start-Transcript -Path $LogPath -Force | Out-Null
    $startedTranscript = $true
}
catch {
    Write-Warning "Could not start transcript log: $($_.Exception.Message)"
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found. Install App Installer first. Log: $LogPath"
}

try {
    if (-not $SkipBaseInstall) {
        Invoke-Step -Name "Installing base dependencies" -Action {
            $basePackages = @(
                "twpayne.chezmoi",
                "Git.Git",
                "Microsoft.PowerShell",
                "GitHub.cli"
            )

            foreach ($pkg in $basePackages) {
                Ensure-WingetPackage -Id $pkg
            }
        }
    }

    Invoke-Step -Name "Resolving chezmoi executable" -Action {
        $script:chezmoiExe = Resolve-Chezmoi
        if (-not $script:chezmoiExe) {
            throw @"
chezmoi not found after install.
Try:
1) Close and reopen terminal
2) Run: winget list --id twpayne.chezmoi
3) Re-run this installer command
Log: $LogPath
"@
        }
        Write-Host "    using chezmoi: $script:chezmoiExe" -ForegroundColor DarkGray
    }

    Set-InstallerEnvData

    $sourcePath = $null
    Invoke-Step -Name "Initializing repository via chezmoi ($Repo)" -Action {
        $initOutput = & $script:chezmoiExe init $Repo 2>&1
        if ($LASTEXITCODE -eq 0) {
            return
        }

        Write-Host "    chezmoi init output:" -ForegroundColor Yellow
        $initOutput | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }

        $sourcePath = Resolve-ExistingSource -Chez $script:chezmoiExe -RepoName $Repo
        if (-not $sourcePath) {
            throw "chezmoi init failed with exit code $LASTEXITCODE"
        }
    }

    if (-not $sourcePath) {
        $sourcePath = & $script:chezmoiExe source-path
        if ($LASTEXITCODE -ne 0) {
            throw "chezmoi source-path failed with exit code $LASTEXITCODE"
        }
    }
    if (-not (Test-Path $sourcePath)) {
        throw "Unable to resolve chezmoi source-path. Got: $sourcePath"
    }

    $bootstrapPath = Resolve-RepoScriptPath -SourcePath $sourcePath -RelativePath "scripts\bootstrap.ps1"
    $validatePath = Resolve-RepoScriptPath -SourcePath $sourcePath -RelativePath "scripts\validate.ps1"
    $migratePath = Resolve-RepoScriptPath -SourcePath $sourcePath -RelativePath "scripts\migrate-secrets.ps1"
    $secretsDepsPath = Resolve-RepoScriptPath -SourcePath $sourcePath -RelativePath "scripts\check-secrets-deps.ps1"
    $linkAiPath = Resolve-RepoScriptPath -SourcePath $sourcePath -RelativePath "scripts\link-ai-configs.ps1"

    if (-not $bootstrapPath) { throw "Bootstrap script not found under source path: $sourcePath" }
    if (-not $validatePath) { throw "Validate script not found under source path: $sourcePath" }

    if ($AutoApply) {
        Invoke-Step -Name "Running bootstrap ($Mode)" -Action {
            if ($SkipBaseInstall) {
                & $bootstrapPath -Mode $Mode -SkipInstall
            } else {
                & $bootstrapPath -Mode $Mode
            }
        }

        if ($UseSymlinkAI -and (Test-Path $linkAiPath)) {
            Invoke-Step -Name "Relinking AI config with symlinks" -Action {
                & $linkAiPath -UseSymlink
            }
        }
        Invoke-Step -Name "Running repository validation" -Action {
            & $validatePath
        }

        if (-not $SkipSecretsChecks) {
            if (Test-Path $migratePath) {
                Invoke-Step -Name "Running legacy secret migration checks" -Action {
                    & $migratePath
                }
            }

            if (Test-Path $secretsDepsPath) {
                Invoke-Step -Name "Running secrets dependency checks" -Action {
                    & $secretsDepsPath
                }
            }
        }

        Write-Host ""
        Write-Host "Setup completed." -ForegroundColor Green
        Write-Host "Profile mode commands: pmode / pclean / pfull" -ForegroundColor Green
        Write-Host "Install log: $LogPath" -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "Repository initialized only (manual apply mode)." -ForegroundColor Green
        Write-Host "Next commands:" -ForegroundColor Yellow
        Write-Host "1) Set-Location '$sourcePath'" -ForegroundColor Yellow
        Write-Host "2) chezmoi apply" -ForegroundColor Yellow
        Write-Host "3) ./scripts/bootstrap.ps1 -Mode $Mode" -ForegroundColor Yellow
        Write-Host "4) ./scripts/validate.ps1" -ForegroundColor Yellow
        if (-not $SkipSecretsChecks) {
            Write-Host "5) ./scripts/migrate-secrets.ps1" -ForegroundColor Yellow
            if (Test-Path $secretsDepsPath) {
                Write-Host "6) ./scripts/check-secrets-deps.ps1" -ForegroundColor Yellow
            }
        }
        Write-Host "Install log: $LogPath" -ForegroundColor Green
    }
}
catch {
    Write-Host ""
    Write-Host "Installation failed during step: $script:CurrentStep" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Log: $LogPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Recovery options:" -ForegroundColor Yellow
    Write-Host "1) Re-run same command (installer is idempotent)." -ForegroundColor Yellow
    Write-Host "2) Re-run skipping base install:" -ForegroundColor Yellow
    Write-Host "   & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/marlonangeli/windots/main/init.ps1'))) -SkipBaseInstall" -ForegroundColor Yellow
    Write-Host "3) Reopen terminal and run option 2 (refreshes PATH in new session)." -ForegroundColor Yellow
    Write-Host "4) Verify chezmoi manually: winget list --id twpayne.chezmoi" -ForegroundColor Yellow
    throw
}
finally {
    if ($startedTranscript) {
        try { Stop-Transcript | Out-Null } catch {}
    }
}
