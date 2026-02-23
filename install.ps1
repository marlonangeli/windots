[CmdletBinding()]
param(
    [string]$Repo = "marlonangeli/windots",

    [ValidateSet("menu", "install", "update", "restore", "quit")]
    [string]$Action,

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
    [string[]]$Modules,

    [string]$RestoreConfigPath
)

$ErrorActionPreference = "Stop"
$script:CurrentStep = "bootstrap"
$script:chezmoiExe = $null
$script:InstallerBoundParameters = @{}
foreach ($boundKey in $PSBoundParameters.Keys) {
    $script:InstallerBoundParameters[$boundKey] = $PSBoundParameters[$boundKey]
}

$loggerPath = if ($PSScriptRoot) { Join-Path $PSScriptRoot "scripts\common\logging.ps1" } else { "" }
if ($loggerPath -and (Test-Path $loggerPath)) {
    . $loggerPath
}
else {
    if (-not (Get-Variable -Name WindotsLogFilePath -Scope Global -ErrorAction SilentlyContinue)) {
        $Global:WindotsLogFilePath = ""
    }

    function Set-WindotsLogFilePath {
        param(
            [Parameter(Mandatory)][string]$Path,
            [switch]$Reset
        )

        $directory = Split-Path -Parent $Path
        if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }

        if ($Reset -or -not (Test-Path $Path)) {
            Set-Content -Path $Path -Value "" -Encoding UTF8
        }

        $Global:WindotsLogFilePath = $Path
    }

    function Write-WindotsLogFileLine {
        param(
            [ValidateSet("INFO", "WARN", "ERROR")]
            [string]$Level = "INFO",
            [Parameter(Mandatory)][string]$Message
        )

        if ([string]::IsNullOrWhiteSpace($Global:WindotsLogFilePath)) {
            return
        }

        Add-Content -Path $Global:WindotsLogFilePath -Value ("[{0}] {1}" -f $Level, $Message) -Encoding UTF8
    }

    function Write-WindotsFallbackLine {
        param(
            [Parameter(Mandatory)][string]$Message,
            [Parameter(Mandatory)][ConsoleColor]$Color,
            [ValidateSet("INFO", "WARN", "ERROR")]
            [string]$Level = "INFO",
            [int]$Indent = 0
        )

        Write-WindotsLogFileLine -Level $Level -Message $Message
        $prefix = if ($Indent -gt 0) { " " * $Indent } else { "" }
        Write-Host ("{0}{1}" -f $prefix, $Message) -ForegroundColor $Color
    }

    function Log-Info { param([Parameter(Mandatory)][string]$Message) Write-WindotsFallbackLine -Message $Message -Color White -Level "INFO" }
    function Log-Step { param([Parameter(Mandatory)][string]$Message) Write-WindotsFallbackLine -Message $Message -Color Cyan -Level "INFO" -Indent 2 }
    function Log-Warn { param([Parameter(Mandatory)][string]$Message) Write-WindotsFallbackLine -Message $Message -Color Yellow -Level "WARN" }
    function Log-Error { param([Parameter(Mandatory)][string]$Message) Write-WindotsFallbackLine -Message $Message -Color Red -Level "ERROR" }
    function Log-Success { param([Parameter(Mandatory)][string]$Message) Write-WindotsFallbackLine -Message $Message -Color Green -Level "INFO" }
    function Log-Option { param([Parameter(Mandatory)][string]$Message) Write-WindotsFallbackLine -Message $Message -Color Magenta -Level "INFO" -Indent 4 }
    function Log-Output { param([Parameter(Mandatory)][string]$Message) Write-WindotsFallbackLine -Message $Message -Color Gray -Level "INFO" -Indent 4 }
    function Log-Module { param([Parameter(Mandatory)][string]$Message) Write-WindotsFallbackLine -Message $Message -Color Cyan -Level "INFO" }
    function Log-ModuleDescription { param([Parameter(Mandatory)][string]$Message) Write-WindotsFallbackLine -Message $Message -Color Gray -Level "INFO" -Indent 4 }
    function Log-Package { param([Parameter(Mandatory)][string]$Message) Write-WindotsFallbackLine -Message $Message -Color Cyan -Level "INFO" -Indent 4 }
    function Log-PackageStatus {
        param(
            [Parameter(Mandatory)][string]$Package,
            [Parameter(Mandatory)][string]$Status,
            [ConsoleColor]$StatusColor = [ConsoleColor]::Green,
            [ValidateSet("INFO", "WARN", "ERROR")]
            [string]$FileLevel = "INFO"
        )

        $message = "package {0} {1}" -f $Package, $Status
        Write-WindotsLogFileLine -Level $FileLevel -Message $message
        Write-Host ("    package {0} " -f $Package) -ForegroundColor Cyan -NoNewline
        Write-Host $Status -ForegroundColor $StatusColor
    }
    function Read-WindotsInput {
        param([Parameter(Mandatory)][string]$Prompt)
        Write-WindotsLogFileLine -Level "INFO" -Message ("Input prompt: {0}" -f $Prompt)
        Write-Host ("    Input: {0}" -f $Prompt) -ForegroundColor Magenta -NoNewline
        Write-Host " " -NoNewline
        return (Read-Host)
    }
    function Confirm-WindotsChoice {
        param(
            [Parameter(Mandatory)][string]$Message,
            [switch]$DefaultYes,
            [switch]$NoPrompt
        )

        if ($NoPrompt) { return [bool]$DefaultYes }
        $hint = if ($DefaultYes) { "(Y/n)" } else { "(y/N)" }
        $value = Read-WindotsInput -Prompt ("{0} {1}" -f $Message, $hint)
        if ([string]::IsNullOrWhiteSpace($value)) { return [bool]$DefaultYes }
        return ($value -in @("y", "Y", "yes", "YES"))
    }
    function Log-NewLine { Write-Host "" }
}

$wingetPath = if ($PSScriptRoot) { Join-Path $PSScriptRoot "scripts\common\winget.ps1" } else { "" }
if ($wingetPath -and (Test-Path $wingetPath)) {
    . $wingetPath
}

$preflightPath = if ($PSScriptRoot) { Join-Path $PSScriptRoot "scripts\common\preflight.ps1" } else { "" }
if ($preflightPath -and (Test-Path $preflightPath)) {
    . $preflightPath
}

$statePath = if ($PSScriptRoot) { Join-Path $PSScriptRoot "scripts\common\state.ps1" } else { "" }
if ($statePath -and (Test-Path $statePath)) {
    . $statePath
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

    $payload = [ordered]@{
        mode = $ModeName
        repo = $Repo
        branch = $Branch
        ref = $Ref
        source_path = $SourcePathValue
        local_repo_path = $LocalRepoPath
        updated_at = (Get-Date).ToString("o")
    }

    if (Get-Command Write-WindotsStateFile -ErrorAction SilentlyContinue) {
        $null = Write-WindotsStateFile -Name "source" -Data $payload
        return
    }

    $stateBase = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $HOME ".local\\share" }
    $stateDir = Join-Path $stateBase "windots\\state"
    if (-not (Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }

    $statePath = Join-Path $stateDir "source.json"
    $payload | ConvertTo-Json | Set-Content -Path $statePath -Encoding UTF8
    Log-Info "source state written: $statePath"
}

function Ensure-WingetPackage {
    param([Parameter(Mandatory)][string]$Id)

    $hasWingetWrapper = $null -ne (Get-Command Test-WingetPackageInstalled -ErrorAction SilentlyContinue) -and
        $null -ne (Get-Command Invoke-WingetInstall -ErrorAction SilentlyContinue)

    $installed = $false
    if ($hasWingetWrapper) {
        $installed = Test-WingetPackageInstalled -Id $Id
    }
    else {
        $probe = winget list --id $Id --exact --source winget --accept-source-agreements 2>$null
        $installed = ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($probe | Out-String)))
    }

    $packageLabel = $Id
    if ($installed) {
        Log-PackageStatus -Package $packageLabel -Status "is installed" -StatusColor Green
        return
    }

    Log-PackageStatus -Package $packageLabel -Status "is not installed" -StatusColor Cyan
    Log-Step ("installing package {0}" -f $packageLabel)

    try {
        if ($hasWingetWrapper) {
            Invoke-WingetInstall -Id $Id
        }
        else {
            $previousPreference = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            try {
                $null = winget install --id $Id --exact --source winget --accept-source-agreements --accept-package-agreements --silent 2>&1
                $wingetExitCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $previousPreference
            }

            if ($wingetExitCode -ne 0) {
                throw "winget install failed for '$Id'"
            }
        }
    }
    catch {
        Log-Error ("failed to install package '{0}'." -f $packageLabel)
        throw
    }

    Log-PackageStatus -Package $packageLabel -Status "installed successfully" -StatusColor Green
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

function Invoke-NativeCommandSafely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CommandPath,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $CommandPath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = @($output)
    }
}

function Request-ShellReloadAndContinue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CommandName,
        [string]$Reason = "The command is not available in PATH yet."
    )

    Log-Warn $Reason
    if ($NoPrompt) {
        return $false
    }

    Log-Option "Reload your shell/terminal to refresh PATH entries."
    Log-Option "After reloading, return here and continue."
    $response = Read-WindotsInput -Prompt "Press Enter to retry, or type 'skip'"
    if ($response -and $response.Trim().ToLowerInvariant() -eq "skip") {
        return $false
    }

    Refresh-ProcessPath
    return ($null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue))
}

function Prompt-Confirm {
    param(
        [Parameter(Mandatory)][string]$Message,
        [switch]$DefaultYes
    )

    return (Confirm-WindotsChoice -Message $Message -DefaultYes:$DefaultYes -NoPrompt:$NoPrompt)
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

    Log-Info $Message
    Log-Info "Available modules: $($Options -join ', ')"
    if ($Default -and $Default.Count -gt 0) {
        Log-Info "Default modules: $($Default -join ', ')"
    }
    $raw = Read-WindotsInput -Prompt "Enter comma-separated modules (empty for default)"
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

    $suffix = if ([string]::IsNullOrWhiteSpace($Default)) { "" } else { " [$Default]" }
    $value = Read-WindotsInput -Prompt "$Label$suffix"
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
    $backupTerminalSettings = Prompt-Confirm -Message "Backup existing Windows Terminal settings before merge?" -DefaultYes

    $env:CHEZMOI_NAME = $name
    $env:CHEZMOI_EMAIL = $email
    $env:CHEZMOI_GITHUB_USERNAME = $github
    $env:CHEZMOI_AZURE_ORG = $azureOrg
    $env:CHEZMOI_AZURE_PROJECT = $azureProject
    $env:CHEZMOI_WT_BACKUP = if ($backupTerminalSettings) { "1" } else { "0" }
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

function Invoke-InstallerPreflight {
    [CmdletBinding()]
    param(
        [ValidateSet("install", "update", "restore")]
        [string]$RequestedAction
    )

    if (Get-Command Invoke-WindotsPreflight -ErrorAction SilentlyContinue) {
        $skipNetwork = $false
        if ($RequestedAction -eq "install" -and -not [string]::IsNullOrWhiteSpace($LocalRepoPath)) {
            $skipNetwork = $true
            Log-Info "Preflight network checks skipped because -LocalRepoPath was provided."
        }

        Invoke-WindotsPreflight -Action $RequestedAction -SkipNetworkChecks:$skipNetwork
        return
    }

    $errors = New-Object System.Collections.Generic.List[string]

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        $errors.Add("winget not found. Install App Installer first.")
    }

    try {
        $processPolicy = Get-ExecutionPolicy -Scope Process
        $userPolicy = Get-ExecutionPolicy -Scope CurrentUser
        $machinePolicy = Get-ExecutionPolicy -Scope LocalMachine
        Log-Info ("execution policy (Process/CurrentUser/LocalMachine): {0}/{1}/{2}" -f $processPolicy, $userPolicy, $machinePolicy)
        if ($userPolicy -in @("Restricted", "AllSigned")) {
            Log-Warn "Execution policy may block scripts. Recommended: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
        }
    }
    catch {
        Log-Warn "Unable to inspect execution policy: $($_.Exception.Message)"
    }

    foreach ($commandName in @("git", "chezmoi", "pwsh")) {
        if (Get-Command $commandName -ErrorAction SilentlyContinue) {
            Log-Info "command detected: $commandName"
            continue
        }

        if ($RequestedAction -eq "install") {
            Log-Warn "command not found (will be installed when applicable): $commandName"
        }
        else {
            $errors.Add("required command not found: $commandName")
        }
    }

    $shouldCheckNetwork = ($RequestedAction -ne "install" -or [string]::IsNullOrWhiteSpace($LocalRepoPath))
    if ($shouldCheckNetwork) {
        $testEndpoint = {
            param([string]$Url)
            try {
                $null = Invoke-WebRequest -Uri $Url -Method Head -TimeoutSec 10 -ErrorAction Stop
                return $true
            }
            catch {
                try {
                    $null = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec 10 -ErrorAction Stop
                    return $true
                }
                catch {
                    return $false
                }
            }
        }

        foreach ($endpoint in @("https://github.com", "https://raw.githubusercontent.com")) {
            $ok = & $testEndpoint $endpoint
            if ($ok) {
                Log-Info "connectivity check: OK ($endpoint)"
            }
            else {
                $errors.Add("Network check failed for '$endpoint'.")
            }
        }
    }

    if ($RequestedAction -in @("update", "restore")) {
        $chez = Resolve-Chezmoi
        if (-not $chez) {
            $errors.Add("chezmoi not found in PATH. Run INSTALL first.")
        }
        else {
            $sourcePath = & $chez source-path 2>$null
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sourcePath)) {
                $errors.Add("chezmoi is not initialized for this user. Run INSTALL first.")
            }
        }
    }

    if ($errors.Count -gt 0) {
        foreach ($message in $errors) {
            Log-Error $message
        }
        throw "Preflight failed with $($errors.Count) error(s)."
    }

    Log-Info "Preflight OK (inline fallback checks)."
}

function Prompt-InstallerAction {
    [CmdletBinding()]
    param()

    function Show-InstallerBanner {
        $bannerPath = if ($PSScriptRoot) { Join-Path $PSScriptRoot "banner.txt" } else { "banner.txt" }
        $banner = ""
        if (Test-Path $bannerPath) {
            $banner = Get-Content -Path $bannerPath -Raw
        }

        if ([string]::IsNullOrWhiteSpace($banner)) {
            $banner = @'
██╗    ██╗██╗███╗   ██╗██████╗  ██████╗ ████████╗███████╗
██║    ██║██║████╗  ██║██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝
██║ █╗ ██║██║██╔██╗ ██║██║  ██║██║   ██║   ██║   ███████╗
██║███╗██║██║██║╚██╗██║██║  ██║██║   ██║   ██║   ╚════██║
╚███╔███╔╝██║██║ ╚████║██████╔╝╚██████╔╝   ██║   ███████║
 ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝╚═════╝  ╚═════╝    ╚═╝   ╚══════╝
'@
        }

        $bannerLines = @($banner -split "`r?`n") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        $bannerText = ($bannerLines | ForEach-Object { " $_" }) -join [Environment]::NewLine

        Log-NewLine

        if ($Host.UI.SupportsVirtualTerminal) {
            Write-Host "`e[38;5;39m$bannerText`e[0m"
            Log-NewLine
            return
        }

        Write-Host $bannerText -ForegroundColor Cyan
        Log-NewLine
    }

    if ($NoPrompt) {
        return "install"
    }

    Show-InstallerBanner

    Log-NewLine
    Log-Option "1) INSTALL"
    Log-Option "2) UPDATE"
    Log-Option "3) RESTORE"
    Log-Option "4) QUIT"

    $selection = Read-WindotsInput -Prompt "Choose action (1-4)"
    switch ($selection) {
        "1" { return "install" }
        "2" { return "update" }
        "3" { return "restore" }
        default { return "quit" }
    }
}

function Resolve-InstallerAction {
    [CmdletBinding()]
    param()

    if ($script:InstallerBoundParameters.ContainsKey("Action") -and -not [string]::IsNullOrWhiteSpace($Action)) {
        return $Action.Trim().ToLowerInvariant()
    }

    $installSwitches = @(
        "Repo", "Branch", "Ref", "RequireNonMain", "LocalRepoPath", "Mode",
        "SkipBaseInstall", "UseSymlinkAI", "SkipSecretsChecks", "AutoApply", "Modules"
    )

    foreach ($key in $installSwitches) {
        if ($script:InstallerBoundParameters.ContainsKey($key)) {
            return "install"
        }
    }

    if ($NoPrompt) {
        return "install"
    }

    return "menu"
}

function Invoke-WindotsWrapperCommand {
    [CmdletBinding()]
    param(
        [ValidateSet("update", "restore")]
        [string]$CommandName
    )

    $script:CurrentStep = "Running $CommandName workflow"
    Invoke-InstallerPreflight -RequestedAction $CommandName

    $script:chezmoiExe = Resolve-Chezmoi
    if (-not $script:chezmoiExe) {
        throw "chezmoi not found in PATH. Run INSTALL first."
    }

    $sourcePath = & $script:chezmoiExe source-path 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sourcePath)) {
        throw "chezmoi source not initialized. Run INSTALL first."
    }

    $resolvedSourcePath = $sourcePath.Trim().Trim('"')
    $windotsPath = Resolve-RepoScriptPath -SourcePath $resolvedSourcePath -RelativePath "scripts\windots.ps1"
    if (-not $windotsPath) {
        throw "Unable to resolve scripts/windots.ps1 from source path '$resolvedSourcePath'."
    }

    $windotsArgs = @{
        Command = $CommandName
        Mode = $Mode
        NoPrompt = [bool]$NoPrompt
        UseSymlinkAI = [bool]$UseSymlinkAI
        SkipSecretsChecks = [bool]$SkipSecretsChecks
    }

    if ($Modules -and $Modules.Count -gt 0) {
        $windotsArgs.Modules = $Modules
    }

    if ($CommandName -eq "restore" -and -not [string]::IsNullOrWhiteSpace($RestoreConfigPath)) {
        $windotsArgs.RestoreConfigPath = $RestoreConfigPath
    }

    if ($CommandName -eq "update") {
        $windotsArgs.SkipInstall = $true
    }

    Log-Step "Running windots $CommandName"
    & $windotsPath @windotsArgs
    if (-not $?) {
        throw "windots $CommandName failed"
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

if (Get-Command Set-WindotsLogFilePath -ErrorAction SilentlyContinue) {
    Set-WindotsLogFilePath -Path $LogPath -Reset
}

$resolvedAction = Resolve-InstallerAction
if ($resolvedAction -eq "menu") {
    $resolvedAction = Prompt-InstallerAction
}

$autoApplyEnabled = if ($script:InstallerBoundParameters.ContainsKey("AutoApply")) {
    [bool]$AutoApply
}
else {
    $true
}

try {
    switch ($resolvedAction) {
        "quit" {
            Log-Info "Installer finished by user choice (QUIT)."
            return
        }
        "update" {
            Invoke-WindotsWrapperCommand -CommandName "update"
            return
        }
        "restore" {
            Invoke-WindotsWrapperCommand -CommandName "restore"
            return
        }
        default {
            Invoke-InstallerPreflight -RequestedAction "install"
        }
    }

    Log-Info "Installer action: $resolvedAction"
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
            $reloaded = Request-ShellReloadAndContinue -CommandName "chezmoi" -Reason "chezmoi was installed but is not available in PATH yet."
            if ($reloaded) {
                $script:chezmoiExe = Resolve-Chezmoi
            }
        }

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

            $localInit = Invoke-NativeCommandSafely -CommandPath $script:chezmoiExe -Arguments @("init", "--source", $resolvedLocalRepo)
            if ($localInit.ExitCode -eq 0) {
                return
            }

            Log-Warn "chezmoi init output:"
            $localInit.Output | ForEach-Object {
                if (-not [string]::IsNullOrWhiteSpace($_)) {
                    Log-Output "$_"
                }
            }
            throw "chezmoi init --source failed with exit code $($localInit.ExitCode)"
        }

        $repoUrl = "https://github.com/$Repo.git"
        Log-Info "using remote repository: $repoUrl (branch: $Branch)"
        $remoteInit = Invoke-NativeCommandSafely -CommandPath $script:chezmoiExe -Arguments @("init", "--branch", $Branch, $repoUrl)
        if ($remoteInit.ExitCode -eq 0) {
            return
        }

        Log-Warn "chezmoi init output:"
        $remoteInit.Output | ForEach-Object {
            if (-not [string]::IsNullOrWhiteSpace($_)) {
                Log-Output "$_"
            }
        }

        $sourcePath = Resolve-ExistingSource -Chez $script:chezmoiExe -RepoName $Repo
        if (-not $sourcePath) {
            throw "chezmoi init failed with exit code $($remoteInit.ExitCode)"
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
    $secretsDepsPath = Resolve-RepoScriptPath -SourcePath $sourcePath -RelativePath "modules\secrets\deps-check.ps1"
    $moduleRegistryPath = Resolve-RepoScriptPath -SourcePath $sourcePath -RelativePath "modules\module-registry.ps1"

    if (-not $bootstrapPath) {
        throw "Bootstrap script not found. source-path='$sourcePath'. Ensure repository root contains .chezmoiroot and scripts/."
    }
    if (-not $validatePath) { throw "Validate script not found under source path: $sourcePath" }

    if ($autoApplyEnabled) {
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
        Log-Option "Next commands:"
        Log-Option "1) Set-Location '$(Join-Path $HOME ".local\share\chezmoi")'"
        Log-Option "2) chezmoi apply"
        Log-Option "3) pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/windots.ps1 -Command bootstrap -Mode $Mode"
        Log-Option "4) pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/windots.ps1 -Command validate"
        if (-not $SkipSecretsChecks) {
            Log-Option "5) pwsh -NoProfile -ExecutionPolicy Bypass -File ./modules/secrets/migrate.ps1"
            if (Test-Path $secretsDepsPath) {
                Log-Option "6) pwsh -NoProfile -ExecutionPolicy Bypass -File ./modules/secrets/deps-check.ps1"
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
    Log-Option "Recovery options:"
    Log-Option "1) Re-run same command (installer is idempotent)."
    Log-Option "2) Re-run skipping base install:"
    Log-Option "& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/marlonangeli/windots/main/install.ps1'))) -SkipBaseInstall"
    Log-Option "3) Reopen terminal and run option 2 (refreshes PATH in new session)."
    Log-Option "4) Verify chezmoi manually: winget list --id twpayne.chezmoi"
    throw
}
