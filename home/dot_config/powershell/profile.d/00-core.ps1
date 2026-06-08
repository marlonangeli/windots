function Test-InteractiveShell {
    [CmdletBinding()]
    param()

    return ($Host.Name -eq "ConsoleHost" -and -not [Console]::IsOutputRedirected)
}

function Add-PathEntryIfMissing {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$PathEntry)

    if ([string]::IsNullOrWhiteSpace($PathEntry)) { return }
    $expanded = $ExecutionContext.InvokeCommand.ExpandString($PathEntry)
    if (-not (Test-Path $expanded)) { return }

    $entries = @($env:PATH -split ";") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($entries -contains $expanded) { return }

    $env:PATH = "$expanded;$env:PATH"
}

function Invoke-ShellInitScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    try {
        $body = & $Command @Arguments 2>$null | Out-String
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($body)) { return $false }
        Invoke-Expression $body
        return $true
    }
    catch {
        return $false
    }
}

function Get-ProfileMode {
    [CmdletBinding()]
    param()

    $global:__WindotsProfileMode
}

function Set-ProfileMode {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet("full", "clean")][string]$Mode)

    $normalized = $Mode.ToLowerInvariant()
    [Environment]::SetEnvironmentVariable("POWERSHELL_PROFILE_MODE", $normalized, "User")
    $env:POWERSHELL_PROFILE_MODE = $normalized
    Write-Host "Profile mode set to '$normalized'. Open a new shell to apply." -ForegroundColor Green
}

function reload { . $PROFILE }
function pmode { Get-ProfileMode }
function pclean { Set-ProfileMode clean }
function pfull { Set-ProfileMode full }

function which {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Command)

    (Get-Command $Command -ErrorAction SilentlyContinue).Source
}

function touch {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    New-Item -ItemType File -Path $Path -Force | Out-Null
}

function mkcd {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location $Path
}

function take { mkcd @args }
