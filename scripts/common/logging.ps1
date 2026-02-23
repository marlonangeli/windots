[CmdletBinding()]
param()

if (-not (Get-Variable -Name WindotsLogFilePath -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:WindotsLogFilePath = ""
}

function Set-WindotsLogFilePath {
    [CmdletBinding()]
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

function Get-WindotsLogFilePath {
    [CmdletBinding()]
    param()

    return $Global:WindotsLogFilePath
}

function Write-WindotsLogFileLine {
    [CmdletBinding()]
    param(
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO",
        [Parameter(Mandatory)][string]$Message
    )

    $path = Get-WindotsLogFilePath
    if ([string]::IsNullOrWhiteSpace($path)) {
        return
    }

    Add-Content -Path $path -Value ("[{0}] {1}" -f $Level, $Message) -Encoding UTF8
}

function Write-WindotsConsoleLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::White,
        [int]$Indent = 0,
        [switch]$NoNewLine
    )

    $prefix = ""
    if ($Indent -gt 0) {
        $prefix = " " * $Indent
    }

    if ($NoNewLine) {
        Write-Host ("{0}{1}" -f $prefix, $Message) -ForegroundColor $Color -NoNewline
        return
    }

    Write-Host ("{0}{1}" -f $prefix, $Message) -ForegroundColor $Color
}

function Write-WindotsLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$FileLevel = "INFO",
        [ConsoleColor]$ConsoleColor = [ConsoleColor]::White,
        [int]$Indent = 0
    )

    Write-WindotsLogFileLine -Level $FileLevel -Message $Message
    Write-WindotsConsoleLine -Message $Message -Color $ConsoleColor -Indent $Indent
}

function Log-Info {
    param([Parameter(Mandatory)][string]$Message)
    Write-WindotsLog -Message $Message -FileLevel "INFO" -ConsoleColor White
}

function Log-Step {
    param([Parameter(Mandatory)][string]$Message)
    Write-WindotsLog -Message $Message -FileLevel "INFO" -ConsoleColor Cyan -Indent 2
}

function Log-Warn {
    param([Parameter(Mandatory)][string]$Message)
    Write-WindotsLog -Message $Message -FileLevel "WARN" -ConsoleColor Yellow
}

function Log-Error {
    param([Parameter(Mandatory)][string]$Message)
    Write-WindotsLog -Message $Message -FileLevel "ERROR" -ConsoleColor Red
}

function Log-Success {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Message)

    Write-WindotsLog -Message $Message -FileLevel "INFO" -ConsoleColor Green
}

function Log-Option {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Message)

    Write-WindotsLog -Message $Message -FileLevel "INFO" -ConsoleColor Magenta -Indent 4
}

function Log-Output {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Message)

    Write-WindotsLog -Message $Message -FileLevel "INFO" -ConsoleColor Gray -Indent 4
}

function Log-Module {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Message)

    Write-WindotsLog -Message $Message -FileLevel "INFO" -ConsoleColor Cyan
}

function Log-ModuleDescription {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Message)

    Write-WindotsLog -Message $Message -FileLevel "INFO" -ConsoleColor Gray -Indent 4
}

function Log-Package {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Message)

    Write-WindotsLog -Message $Message -FileLevel "INFO" -ConsoleColor Cyan -Indent 4
}

function Log-PackageStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Package,
        [Parameter(Mandatory)][string]$Status,
        [ConsoleColor]$StatusColor = [ConsoleColor]::Green,
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$FileLevel = "INFO"
    )

    $message = "package {0} {1}" -f $Package, $Status
    Write-WindotsLogFileLine -Level $FileLevel -Message $message
    Write-WindotsConsoleLine -Message ("package {0} " -f $Package) -Color Cyan -Indent 4 -NoNewLine
    Write-WindotsConsoleLine -Message $Status -Color $StatusColor
}

function Read-WindotsInput {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Prompt)

    Write-WindotsLogFileLine -Level "INFO" -Message ("Input prompt: {0}" -f $Prompt)
    Write-WindotsConsoleLine -Message ("Input: {0}" -f $Prompt) -Color Magenta -Indent 4 -NoNewLine
    Write-Host " " -NoNewline
    return (Read-Host)
}

function Confirm-WindotsChoice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [switch]$DefaultYes,
        [switch]$NoPrompt
    )

    if ($NoPrompt) {
        return [bool]$DefaultYes
    }

    $hint = if ($DefaultYes) { "(Y/n)" } else { "(y/N)" }
    $value = Read-WindotsInput -Prompt ("{0} {1}" -f $Message, $hint)
    if ([string]::IsNullOrWhiteSpace($value)) {
        return [bool]$DefaultYes
    }

    return ($value -in @("y", "Y", "yes", "YES"))
}

function Log-NewLine {
    Write-Host ""
}
