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
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete -ErrorAction SilentlyContinue
}

$global:__TerminalIconsLoaded = $false
function Enable-TerminalIcons {
    if ($global:__TerminalIconsLoaded) { return }
    if (Get-Module -ListAvailable -Name Terminal-Icons) {
        Import-Module Terminal-Icons -ErrorAction SilentlyContinue
        $global:__TerminalIconsLoaded = $true
    }
}

$global:__ZoxideLoaded = $false
function Enable-Zoxide {
    if ($global:__ZoxideLoaded) { return }
    if (Get-Command zoxide -ErrorAction SilentlyContinue) {
        Invoke-Expression (& { zoxide init powershell | Out-String })
    }
    $global:__ZoxideLoaded = $true
}

function z {
    Enable-Zoxide
    if (Get-Command __zoxide_z -ErrorAction SilentlyContinue) { __zoxide_z @args }
}

function zi {
    Enable-Zoxide
    if (Get-Command __zoxide_zi -ErrorAction SilentlyContinue) { __zoxide_zi @args }
}

$global:__PoshInitialized = $false
$global:__OriginalPrompt = $function:prompt
function Enable-PoshPrompt {
    if ($global:__PoshInitialized) { return }
    if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) { return }

    $themeFile = Join-Path $env:POSH_THEMES_PATH "catppuccin_mocha.omp.json"
    if (-not (Test-Path $themeFile)) { return }

    oh-my-posh init pwsh --config $themeFile | Invoke-Expression
    $global:__PoshInitialized = $true
}

if (Test-InteractiveShell -and $global:__PSProfileMode -eq "full") {
    function global:prompt {
        Enable-PoshPrompt
        if ($global:__PoshInitialized) {
            & $function:prompt
            return
        }
        & $global:__OriginalPrompt
    }
}

# mise (tool version manager) - optional activation
if (Get-Command mise -ErrorAction SilentlyContinue) {
    try {
        mise activate pwsh | Out-String | Invoke-Expression
    }
    catch {
        Write-Verbose "mise activation failed: $_"
    }
}
