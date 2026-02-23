[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot "logging.ps1")

function Get-WindotsWingetErrorText {
    [CmdletBinding()]
    param([object[]]$Output)

    if (-not $Output) {
        return ""
    }

    return (($Output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine)
}

function Test-WindotsWingetMsstoreFailure {
    [CmdletBinding()]
    param([string]$ErrorText)

    if ([string]::IsNullOrWhiteSpace($ErrorText)) {
        return $false
    }

    return ($ErrorText -match "0x8a15005e" -or $ErrorText -match "Failed when searching source:\s*msstore")
}

function Invoke-WindotsWingetRaw {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Args,
        [string]$Operation = "winget"
    )

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget not found in PATH"
    }

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & winget @Args 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    return [pscustomobject]@{
        Operation = $Operation
        ExitCode = $exitCode
        Output = @($output)
        ErrorText = Get-WindotsWingetErrorText -Output $output
        Args = @($Args)
    }
}

function Invoke-WindotsWingetStoreBypass {
    [CmdletBinding()]
    param([switch]$Enable)

    $state = if ($Enable) { "enable" } else { "disable" }
    $args = @("settings", "--$state", "BypassCertificatePinningForMicrosoftStore")

    try {
        $result = Invoke-WindotsWingetRaw -Args $args -Operation "settings-$state"
        if ($result.ExitCode -ne 0) {
            Log-Warn "winget settings $state for BypassCertificatePinningForMicrosoftStore failed."
            return $false
        }
        return $true
    }
    catch {
        Log-Warn "winget settings $state for BypassCertificatePinningForMicrosoftStore failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-WingetSourceDisable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$IgnoreErrors
    )

    $result = Invoke-WindotsWingetRaw -Args @("source", "disable", "--name", $Name) -Operation "source-disable"
    if ($result.ExitCode -eq 0) {
        Log-Info "winget source disabled: $Name"
        return
    }

    if ($IgnoreErrors) {
        Log-Warn "Unable to disable winget source '$Name'. Continuing."
        return
    }

    throw "Failed to disable winget source '$Name'."
}

function Invoke-WindotsWingetWithFallback {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Args,
        [Parameter(Mandatory)][string]$Operation,
        [string]$Id
    )

    $first = Invoke-WindotsWingetRaw -Args $Args -Operation $Operation
    if ($first.ExitCode -eq 0) {
        return $first
    }

    if (-not (Test-WindotsWingetMsstoreFailure -ErrorText $first.ErrorText)) {
        throw "winget $Operation failed for '$Id' (exit $($first.ExitCode))."
    }

    Log-Warn ("winget $Operation failed due to msstore certificate/source issue. Applying fallback plan B.")
    Invoke-WingetSourceDisable -Name "msstore" -IgnoreErrors

    $second = Invoke-WindotsWingetRaw -Args $Args -Operation ("$Operation-retry")
    if ($second.ExitCode -eq 0) {
        return $second
    }

    if ($Id -eq "Microsoft.AppInstaller") {
        $bypassEnabled = Invoke-WindotsWingetStoreBypass -Enable
        try {
            Log-Warn "Retrying App Installer upgrade with certificate pinning bypass enabled."
            $updateArgs = @(
                "upgrade",
                "--id", "Microsoft.AppInstaller",
                "--exact",
                "--source", "winget",
                "--accept-source-agreements",
                "--accept-package-agreements",
                "--silent"
            )
            $updateResult = Invoke-WindotsWingetRaw -Args $updateArgs -Operation "upgrade-appinstaller"
            if ($updateResult.ExitCode -eq 0) {
                $third = Invoke-WindotsWingetRaw -Args $Args -Operation ("$Operation-retry2")
                if ($third.ExitCode -eq 0) {
                    return $third
                }
            }
        }
        finally {
            if ($bypassEnabled) {
                $null = Invoke-WindotsWingetStoreBypass
            }
        }
    }

    $message = @(
        "winget $Operation failed for '$Id' after fallback."
        "exit_code_initial=$($first.ExitCode)"
        "exit_code_retry=$($second.ExitCode)"
        "command=winget $($Args -join ' ')"
    ) -join " | "

    throw $message
}

function Test-WingetPackageInstalled {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Id)

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        return $false
    }

    $args = @(
        "list",
        "--id", $Id,
        "--exact",
        "--source", "winget",
        "--accept-source-agreements"
    )

    $result = Invoke-WindotsWingetRaw -Args $args -Operation "list"
    if ($result.ExitCode -ne 0) {
        return $false
    }

    $text = $result.ErrorText
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $false
    }

    if ($text -match "No installed package found") {
        return $false
    }

    return $true
}

function Invoke-WingetInstall {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Id,
        [string[]]$ExtraArgs = @()
    )

    $args = @(
        "install",
        "--id", $Id,
        "--exact",
        "--source", "winget",
        "--accept-source-agreements",
        "--accept-package-agreements",
        "--silent"
    ) + @($ExtraArgs)

    $null = Invoke-WindotsWingetWithFallback -Args $args -Operation "install" -Id $Id
}

function Invoke-WingetUpgrade {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Id,
        [string[]]$ExtraArgs = @()
    )

    $args = @(
        "upgrade",
        "--id", $Id,
        "--exact",
        "--source", "winget",
        "--accept-source-agreements",
        "--accept-package-agreements",
        "--silent"
    ) + @($ExtraArgs)

    $null = Invoke-WindotsWingetWithFallback -Args $args -Operation "upgrade" -Id $Id
}
