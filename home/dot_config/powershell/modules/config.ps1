# ============================================
# Environment Variables & Configuration
# ============================================

$env:DOTNET_CLI_TELEMETRY_OPTOUT = 1
$env:POWERSHELL_TELEMETRY_OPTOUT = 1
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = 1

if ([string]::IsNullOrWhiteSpace($env:EDITOR)) { $env:EDITOR = "zed" }
if ([string]::IsNullOrWhiteSpace($env:VISUAL)) { $env:VISUAL = $env:EDITOR }

function Test-InteractiveShell {
    $Host.Name -eq "ConsoleHost" -and -not [Console]::IsOutputRedirected
}

if (Test-InteractiveShell) {
    Set-PSReadLineOption -EditMode Windows -PredictionSource History -PredictionViewStyle ListView -HistorySearchCursorMovesToEnd -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward -ErrorAction SilentlyContinue
}

function Add-PathEntryIfMissing {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$PathEntry)

    if ([string]::IsNullOrWhiteSpace($PathEntry)) { return }
    if (-not (Test-Path $PathEntry)) { return }

    $entries = @($env:PATH -split ";") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($entries -contains $PathEntry) { return }

    $env:PATH = "$PathEntry;$env:PATH"
}

function Invoke-ShellInitScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    try {
        $scriptBody = & $Command @Arguments 2>$null | Out-String
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($scriptBody)) {
            return $false
        }

        Invoke-Expression $scriptBody
        return $true
    }
    catch {
        return $false
    }
}

$global:__TerminalIconsLoaded = $false
function Enable-TerminalIcons {
    if ($global:__TerminalIconsLoaded) { return }
    if (Get-Module -ListAvailable -Name Terminal-Icons) {
        Import-Module Terminal-Icons -ErrorAction SilentlyContinue
        $global:__TerminalIconsLoaded = $true
    }
}

$global:__PoshGitLoaded = $false
function Enable-PoshGit {
    if ($global:__PoshGitLoaded) { return }
    if (Get-Module -ListAvailable -Name posh-git) {
        Import-Module posh-git -ErrorAction SilentlyContinue
        $global:__PoshGitLoaded = $true
    }
}

$global:__ZoxideLoaded = $false
function Enable-Zoxide {
    if ($global:__ZoxideLoaded) { return }
    if (-not (Get-Command zoxide -ErrorAction SilentlyContinue)) { return }

    if (Invoke-ShellInitScript -Command "zoxide" -Arguments @("init", "powershell")) {
        $global:__ZoxideLoaded = $true
    }
}

function z {
    Enable-Zoxide
    if (Get-Command __zoxide_z -ErrorAction SilentlyContinue) { __zoxide_z @args }
}

function zi {
    Enable-Zoxide
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        Write-Warning "zi requires 'fzf'. Install it or use 'z'."
        return
    }

    if (Get-Command __zoxide_zi -ErrorAction SilentlyContinue) { __zoxide_zi @args }
}

$global:__MiseInitialized = $global:__MiseInitialized -as [bool]
$global:__MiseActivationAttempted = $global:__MiseActivationAttempted -as [bool]
$global:__MiseCompletionInitialized = $global:__MiseCompletionInitialized -as [bool]
$global:__MiseCompletionAttempted = $global:__MiseCompletionAttempted -as [bool]

function Invoke-MiseActivationScript {
    [CmdletBinding()]
    param()

    $previousNotFoundAutoInstall = [Environment]::GetEnvironmentVariable("MISE_NOT_FOUND_AUTO_INSTALL", "Process")
    [Environment]::SetEnvironmentVariable("MISE_NOT_FOUND_AUTO_INSTALL", "0", "Process")

    try {
        return (Invoke-ShellInitScript -Command "mise" -Arguments @("activate", "pwsh"))
    }
    finally {
        if ([string]::IsNullOrWhiteSpace($previousNotFoundAutoInstall)) {
            [Environment]::SetEnvironmentVariable("MISE_NOT_FOUND_AUTO_INSTALL", $null, "Process")
        }
        else {
            [Environment]::SetEnvironmentVariable("MISE_NOT_FOUND_AUTO_INSTALL", $previousNotFoundAutoInstall, "Process")
        }
    }
}

function Enable-Mise {
    if ($global:__MiseInitialized) { return $true }

    $miseShims = Join-Path $env:LOCALAPPDATA "mise\shims"
    Add-PathEntryIfMissing -PathEntry $miseShims

    if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
        return $false
    }

    if ($global:__MiseActivationAttempted) {
        return $false
    }

    $global:__MiseActivationAttempted = $true
    if (Invoke-MiseActivationScript) {
        $global:__MiseInitialized = $true
        return $true
    }

    return $false
}

function Enable-MiseCompletion {
    if ($global:__MiseCompletionInitialized) { return $true }

    if (-not (Test-InteractiveShell)) { return $false }
    if (-not (Get-Command usage -ErrorAction SilentlyContinue)) { return $false }
    if (-not (Enable-Mise)) { return $false }

    if ($global:__MiseCompletionAttempted) {
        return $false
    }

    $global:__MiseCompletionAttempted = $true
    if (Invoke-ShellInitScript -Command "mise" -Arguments @("completion", "powershell")) {
        $global:__MiseCompletionInitialized = $true
        return $true
    }

    return $false
}

$global:__PoshInitialized = $false
$global:__OriginalPrompt = $function:prompt
function Enable-PoshPrompt {
    if ($global:__PoshInitialized) { return }
    if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) { return }

    if ([string]::IsNullOrWhiteSpace($env:POSH_THEMES_PATH)) {
        $env:POSH_THEMES_PATH = Join-Path $env:LOCALAPPDATA "Programs\oh-my-posh\themes"
    }

    $themeFile = Join-Path $env:POSH_THEMES_PATH "catppuccin_mocha.omp.json"
    if (-not (Test-Path $themeFile)) { return }

    oh-my-posh init pwsh --config $themeFile | Invoke-Expression
    $global:__PoshInitialized = $true
}

if (Test-InteractiveShell) {
    Enable-Mise | Out-Null
}

if (Test-InteractiveShell -and $global:__PSProfileMode -eq "full") {
    Enable-PoshGit

    function global:prompt {
        Enable-MiseCompletion | Out-Null
        Enable-PoshPrompt
        if ($global:__PoshInitialized) {
            & $function:prompt
            return
        }
        & $global:__OriginalPrompt
    }
}

if (Test-InteractiveShell) {
    Set-PSReadLineKeyHandler -Key Tab -ScriptBlock {
        if (Get-Command Enable-MiseCompletion -ErrorAction SilentlyContinue) {
            Enable-MiseCompletion | Out-Null
        }
        [Microsoft.PowerShell.PSConsoleReadLine]::MenuComplete()
    } -ErrorAction SilentlyContinue
}
