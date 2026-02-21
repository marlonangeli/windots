[CmdletBinding()]
param(
    [string]$Repo = "marlonangeli/windots",

    [string]$Branch = "main",
    [string]$Ref,
    [switch]$RequireNonMain,
    [string]$LocalRepoPath,

    [ValidateSet("full", "clean")]
    [string]$Mode = "full",

    [switch]$SkipBaseInstall,
    [switch]$UseSymlinkAI,
    [switch]$SkipSecretsChecks,
    [string]$LogPath,
    [switch]$AutoApply,
    [switch]$NoPrompt,
    [string[]]$Modules
)

$ErrorActionPreference = "Stop"
$script:CurrentStep = "bootstrap"
$script:chezmoiExe = $null
$startedTranscript = $false

$loggerPath = if ($PSScriptRoot) { Join-Path $PSScriptRoot "common\logging.ps1" } else { "" }
if ($loggerPath -and (Test-Path $loggerPath)) {
    . $loggerPath
}
else {
    function Log-Info { param([Parameter(Mandatory)][string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Gray }
    function Log-Step { param([Parameter(Mandatory)][string]$Message) Write-Host "==> $Message" -ForegroundColor Cyan }
    function Log-Warn { param([Parameter(Mandatory)][string]$Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
    function Log-Error { param([Parameter(Mandatory)][string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
    function Log-NewLine { Write-Host "" }
}

function Write-Step {
    param([string]$Message)
    $script:CurrentStep = $Message
    Log-Step $Message
}

function Assert-SafeRefName {
    param(
        [Parameter(Mandatory)][string]$Value,
        [Parameter(Mandatory)][string]$Label
    )

    if ($Value -notmatch '^[A-Za-z0-9._/-]+$') {
        throw "Invalid $Label '$Value'. Allowed chars: A-Z a-z 0-9 . _ / -"
    }
}

function Assert-SafeRepoName {
    param([Parameter(Mandatory)][string]$Value)

    if ($Value -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
        throw "Invalid Repo '$Value'. Expected format: <owner>/<repo>"
    }
}

function Assert-LocalRepoPath {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return
    }

    if (-not (Test-Path $PathValue)) {
        throw "LocalRepoPath not found: $PathValue"
    }

    $marker = Join-Path $PathValue ".chezmoiroot"
    if (-not (Test-Path $marker)) {
        throw "LocalRepoPath must contain .chezmoiroot: $PathValue"
    }
}

function Write-SourceState {
    param(
        [Parameter(Mandatory)][string]$ModeName,
        [string]$SourcePathValue
    )

    $stateBase = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $HOME ".local\\share" }
    $stateDir = Join-Path $stateBase "windots\\state"
    if (-not (Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }

    $payload = [ordered]@{
        mode = $ModeName
        repo = $Repo
        branch = $Branch
        ref = $Ref
        source_path = $SourcePathValue
        local_repo_path = $LocalRepoPath
        updated_at = (Get-Date).ToString("o")
    }

    $statePath = Join-Path $stateDir "source.json"
    $payload | ConvertTo-Json | Set-Content -Path $statePath -Encoding UTF8
    Log-Info "source state written: $statePath"
}

function Ensure-WingetPackage {
    param([Parameter(Mandatory)][string]$Id)

    $installed = winget list --id $Id --exact --accept-source-agreements 2>$null
    if ($LASTEXITCODE -eq 0 -and $installed) {
        Log-Info "already installed: $Id"
        return
    }

    Log-Warn "installing: $Id"
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

function Test-GumAvailable {
    return $null -ne (Get-Command gum -ErrorAction SilentlyContinue)
}

function Prompt-Confirm {
    param(
        [Parameter(Mandatory)][string]$Message,
        [switch]$DefaultYes
    )

    if ($NoPrompt) { return [bool]$DefaultYes }

    if (Test-GumAvailable) {
        try {
            & gum confirm $Message
            return ($LASTEXITCODE -eq 0)
        }
        catch {}
    }

    $hint = if ($DefaultYes) { "(Y/n)" } else { "(y/N)" }
    $value = Read-Host "$Message $hint"
    if ([string]::IsNullOrWhiteSpace($value)) { return [bool]$DefaultYes }
    return $value -in @("y", "Y", "yes", "YES")
}

function Prompt-MultiSelect {
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][string[]]$Options,
        [string[]]$Default = @()
    )

    if ($NoPrompt) {
        if ($Default -and $Default.Count -gt 0) { return $Default }
        return @()
    }

    if (Test-GumAvailable) {
        try {
            $selected = & gum choose --no-limit --header $Message @Options
            if ($LASTEXITCODE -eq 0 -and $selected) {
                if ($selected -is [string]) { return @($selected) }
                return @($selected | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            }
        }
        catch {}
    }

    Log-Info "Available modules: $($Options -join ', ')"
    if ($Default -and $Default.Count -gt 0) {
        Log-Info "Default modules: $($Default -join ', ')"
    }
    $raw = Read-Host "Enter comma-separated modules (empty for default)"
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @($Default)
    }

    return @(
        $raw -split "," |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function Prompt-OrDefault {
    param(
        [Parameter(Mandatory)][string]$Label,
        [string]$Default = ""
    )

    if ($NoPrompt) { return $Default }

    if (Test-GumAvailable) {
        try {
            $placeholder = if ([string]::IsNullOrWhiteSpace($Default)) { $Label } else { "$Label [$Default]" }
            $value = & gum input --placeholder $placeholder
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($value)) {
                return $value
            }
        }
        catch {}
    }

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
        Log-Info "existing chezmoi source detected and matches repo: $remote"
        return $sourcePath
    }

    throw "Existing chezmoi source points to a different remote: $remote"
}

function Resolve-RepoRootFromSource {
    param([Parameter(Mandatory)][string]$SourcePath)

    $trimmed = $SourcePath.Trim().Trim('"')
    $candidates = @($trimmed)

    $parent = Split-Path -Parent $trimmed
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        $candidates += $parent
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (-not (Test-Path $candidate)) {
            continue
        }

        $current = (Resolve-Path $candidate).Path
        while (-not [string]::IsNullOrWhiteSpace($current)) {
            $marker = Join-Path $current ".chezmoiroot"
            if (Test-Path $marker) {
                return $current
            }

            $next = Split-Path -Parent $current
            if ([string]::IsNullOrWhiteSpace($next) -or $next -eq $current) {
                break
            }
            $current = $next
        }
    }

    return $null
}

function Resolve-RepoScriptPath {
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$RelativePath
    )

    $trimmedSource = $SourcePath.Trim().Trim('"')
    $sourceParent = Split-Path -Parent $trimmedSource
    $defaultRoot = Join-Path $HOME ".local\\share\\chezmoi"
    $repoRoot = Resolve-RepoRootFromSource -SourcePath $trimmedSource

    if (-not $repoRoot) {
        $repoRoot = $trimmedSource
    }

    $candidates = @(
        (Join-Path $repoRoot $RelativePath),
        (Join-Path $defaultRoot $RelativePath),
        (Join-Path $trimmedSource $RelativePath),
        (Join-Path $sourceParent $RelativePath)
    )

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        Log-Info "checking script path: $candidate"
        if (Test-Path $candidate) {
            Log-Info "resolved script path: $candidate"
            return $candidate
        }
    }

    return $null
}

function Resolve-ModuleSelection {
    param(
        [string]$RegistryPath,
        [ValidateSet("full", "clean")][string]$ModeName,
        [string[]]$Preselected
    )

    if ($Preselected -and $Preselected.Count -gt 0) {
        return @($Preselected)
    }

    if ($NoPrompt -or [string]::IsNullOrWhiteSpace($RegistryPath) -or -not (Test-Path $RegistryPath)) {
        return @()
    }

    $customize = Prompt-Confirm -Message "Customize module selection for mode '$ModeName'?"
    if (-not $customize) {
        return @()
    }

    try {
        . $RegistryPath

        $modulesDir = Split-Path -Parent $RegistryPath
        $scriptsRoot = Split-Path -Parent $modulesDir
        $available = Get-WindotsModuleRegistry -ScriptsRoot $scriptsRoot | Select-Object -ExpandProperty Name
        $defaults = Get-WindotsDefaultModules -Mode $ModeName
        $selected = Prompt-MultiSelect -Message "Select modules to execute" -Options $available -Default $defaults
        if (-not $selected -or $selected.Count -eq 0) {
            return @($defaults)
        }

        return @($selected)
    }
    catch {
        Log-Warn "Failed to resolve module selection UI. Using defaults. Error: $($_.Exception.Message)"
        return @()
    }
}

Assert-SafeRepoName -Value $Repo
Assert-SafeRefName -Value $Branch -Label "Branch"
if (-not [string]::IsNullOrWhiteSpace($Ref)) {
    Assert-SafeRefName -Value $Ref -Label "Ref"
}

if ($RequireNonMain -and [string]::IsNullOrWhiteSpace($Ref) -and [string]::IsNullOrWhiteSpace($LocalRepoPath) -and $Branch -eq "main") {
    throw "-RequireNonMain set but Branch is 'main' and Ref is empty. Choose -Branch, -Ref, or -LocalRepoPath."
}

Assert-LocalRepoPath -PathValue $LocalRepoPath

if (-not $LogPath) {
    $LogPath = Join-Path $env:TEMP ("windots-install-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
}

try {
    Start-Transcript -Path $LogPath -Force | Out-Null
    $startedTranscript = $true
}
catch {
    Log-Warn "Could not start transcript log: $($_.Exception.Message)"
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found. Install App Installer first. Log: $LogPath"
}

try {
    Log-Info "Installer source selector:"
    Log-Info "repo=$Repo branch=$Branch ref=$Ref local=$LocalRepoPath"

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
        Log-Info "using chezmoi: $script:chezmoiExe"
    }

    Set-InstallerEnvData

    $sourcePath = $null
    Invoke-Step -Name "Initializing repository via chezmoi ($Repo)" -Action {
        if (-not [string]::IsNullOrWhiteSpace($LocalRepoPath)) {
            $resolvedLocalRepo = (Resolve-Path $LocalRepoPath).Path
            Log-Info "using local repository source: $resolvedLocalRepo"

            $initOutput = & $script:chezmoiExe init --source $resolvedLocalRepo 2>&1
            if ($LASTEXITCODE -eq 0) {
                return
            }

            Log-Warn "chezmoi init output:"
            $initOutput | ForEach-Object { Log-Warn "$_" }
            throw "chezmoi init --source failed with exit code $LASTEXITCODE"
        }

        $repoUrl = "https://github.com/$Repo.git"
        Log-Info "using remote repository: $repoUrl (branch: $Branch)"
        $initOutput = & $script:chezmoiExe init --branch $Branch $repoUrl 2>&1
        if ($LASTEXITCODE -eq 0) {
            return
        }

        Log-Warn "chezmoi init output:"
        $initOutput | ForEach-Object { Log-Warn "$_" }

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
    $sourcePath = $sourcePath.Trim().Trim('"')
    if (-not (Test-Path $sourcePath)) {
        throw "Unable to resolve chezmoi source-path. Got: $sourcePath"
    }
    Log-Info "chezmoi source-path: $sourcePath"

    if (-not [string]::IsNullOrWhiteSpace($Ref) -and [string]::IsNullOrWhiteSpace($LocalRepoPath)) {
        Invoke-Step -Name "Checking out requested ref ($Ref)" -Action {
            $repoRoot = Resolve-RepoRootFromSource -SourcePath $sourcePath
            if (-not $repoRoot) {
                throw "Could not resolve repository root from source path: $sourcePath"
            }

            git -C $repoRoot fetch --all --tags
            if ($LASTEXITCODE -ne 0) {
                throw "git fetch failed for source repo: $repoRoot"
            }

            git -C $repoRoot checkout $Ref
            if ($LASTEXITCODE -ne 0) {
                throw "git checkout failed for ref '$Ref' in repo: $repoRoot"
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($LocalRepoPath)) {
        Write-SourceState -ModeName "local" -SourcePathValue $sourcePath
    }
    elseif (-not [string]::IsNullOrWhiteSpace($Ref)) {
        Write-SourceState -ModeName "ref" -SourcePathValue $sourcePath
    }
    else {
        Write-SourceState -ModeName "branch" -SourcePathValue $sourcePath
    }

    $bootstrapPath = Resolve-RepoScriptPath -SourcePath $sourcePath -RelativePath "scripts\bootstrap.ps1"
    $validatePath = Resolve-RepoScriptPath -SourcePath $sourcePath -RelativePath "scripts\validate.ps1"
    $secretsDepsPath = Resolve-RepoScriptPath -SourcePath $sourcePath -RelativePath "scripts\check-secrets-deps.ps1"
    $moduleRegistryPath = Resolve-RepoScriptPath -SourcePath $sourcePath -RelativePath "scripts\modules\module-registry.ps1"

    if (-not $bootstrapPath) {
        throw "Bootstrap script not found. source-path='$sourcePath'. Ensure repository root contains .chezmoiroot and scripts/."
    }
    if (-not $validatePath) { throw "Validate script not found under source path: $sourcePath" }

    if ($AutoApply) {
        $selectedModules = Resolve-ModuleSelection -RegistryPath $moduleRegistryPath -ModeName $Mode -Preselected $Modules

        Invoke-Step -Name "Running bootstrap ($Mode)" -Action {
            $bootstrapArgs = @{
                Mode = $Mode
                SkipInstall = [bool]$SkipBaseInstall
                UseSymlinkAI = [bool]$UseSymlinkAI
                NoPrompt = [bool]$NoPrompt
                IncludeSecretsChecks = (-not [bool]$SkipSecretsChecks)
            }

            if ($selectedModules -and $selectedModules.Count -gt 0) {
                $bootstrapArgs.Modules = $selectedModules
            }

            & $bootstrapPath @bootstrapArgs
        }

        Invoke-Step -Name "Running repository validation" -Action {
            & $validatePath
        }

        Log-NewLine
        Log-Info "Setup completed."
        Log-Info "Profile mode commands: pmode / pclean / pfull"
        Log-Info "Install log: $LogPath"
    }
    else {
        Log-NewLine
        Log-Info "Repository initialized only (manual apply mode)."
        Log-Warn "Next commands:"
        Log-Warn "1) Set-Location '$(Join-Path $HOME ".local\share\chezmoi")'"
        Log-Warn "2) chezmoi apply"
        Log-Warn "3) pwsh ./scripts/windots.ps1 -Command bootstrap -Mode $Mode"
        Log-Warn "4) pwsh ./scripts/windots.ps1 -Command validate"
        Log-Warn "5) (legacy/manual) ./scripts/bootstrap.ps1 -Mode $Mode"
        if (-not $SkipSecretsChecks) {
            Log-Warn "6) ./scripts/migrate-secrets.ps1"
            if (Test-Path $secretsDepsPath) {
                Log-Warn "7) ./scripts/check-secrets-deps.ps1"
            }
        }
        Log-Info "Install log: $LogPath"
    }
}
catch {
    Log-NewLine
    Log-Error "Installation failed during step: $script:CurrentStep"
    Log-Error "Error: $($_.Exception.Message)"
    Log-Warn "Log: $LogPath"
    Log-NewLine
    Log-Warn "Recovery options:"
    Log-Warn "1) Re-run same command (installer is idempotent)."
    Log-Warn "2) Re-run skipping base install:"
    Log-Warn "   & ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/marlonangeli/windots/main/install.ps1'))) -SkipBaseInstall"
    Log-Warn "3) Reopen terminal and run option 2 (refreshes PATH in new session)."
    Log-Warn "4) Verify chezmoi manually: winget list --id twpayne.chezmoi"
    throw
}
finally {
    if ($startedTranscript) {
        try { Stop-Transcript | Out-Null } catch {}
    }
}
