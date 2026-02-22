[CmdletBinding()]
param()

$loggingPath = Join-Path $PSScriptRoot "logging.ps1"
if (Test-Path $loggingPath) {
    . $loggingPath
}

if (-not (Get-Command Log-Info -ErrorAction SilentlyContinue)) {
    function Log-Info { param([Parameter(Mandatory)][string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Gray }
    function Log-Warn { param([Parameter(Mandatory)][string]$Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
    function Log-Error { param([Parameter(Mandatory)][string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
    function Log-Step { param([Parameter(Mandatory)][string]$Message) Write-Host "==> $Message" -ForegroundColor Cyan }
}

function Test-WindotsHttpEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Url,
        [int]$TimeoutSeconds = 10
    )

    $result = [ordered]@{
        Url = $Url
        Success = $false
        StatusCode = 0
        Error = ""
    }

    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -TimeoutSec $TimeoutSeconds -ErrorAction Stop
        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
            $result.Success = $true
            $result.StatusCode = [int]$response.StatusCode
            return [pscustomobject]$result
        }
    }
    catch {
        $result.Error = $_.Exception.Message
    }

    try {
        $response = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec $TimeoutSeconds -ErrorAction Stop
        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
            $result.Success = $true
            $result.StatusCode = [int]$response.StatusCode
            $result.Error = ""
            return [pscustomobject]$result
        }
    }
    catch {
        $result.Error = $_.Exception.Message
    }

    return [pscustomobject]$result
}

function Get-WindotsExecutionPolicyState {
    [CmdletBinding()]
    param()

    $scopes = @("MachinePolicy", "UserPolicy", "Process", "CurrentUser", "LocalMachine")
    $state = [ordered]@{}

    foreach ($scope in $scopes) {
        try {
            $state[$scope] = (Get-ExecutionPolicy -Scope $scope)
        }
        catch {
            $state[$scope] = "Unknown"
        }
    }

    return [pscustomobject]$state
}

function Test-WindotsChezmoiInitialized {
    [CmdletBinding()]
    param(
        [string]$ChezmoiCommand = "chezmoi"
    )

    if (-not (Get-Command $ChezmoiCommand -ErrorAction SilentlyContinue)) {
        return [pscustomobject]@{
            IsInitialized = $false
            SourcePath = ""
            Error = "chezmoi not found in PATH"
        }
    }

    $sourcePath = & $ChezmoiCommand source-path 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sourcePath)) {
        return [pscustomobject]@{
            IsInitialized = $false
            SourcePath = ""
            Error = "chezmoi source-path returned empty"
        }
    }

    $trimmed = $sourcePath.Trim().Trim('"')
    if (-not (Test-Path $trimmed)) {
        return [pscustomobject]@{
            IsInitialized = $false
            SourcePath = $trimmed
            Error = "chezmoi source-path does not exist"
        }
    }

    return [pscustomobject]@{
        IsInitialized = $true
        SourcePath = $trimmed
        Error = ""
    }
}

function Test-WindotsWingetSource {
    [CmdletBinding()]
    param()

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        return [pscustomobject]@{
            HasWinget = $false
            HasWingetSource = $false
            Error = "winget not found"
        }
    }

    $output = winget source list 2>&1
    if ($LASTEXITCODE -ne 0) {
        return [pscustomobject]@{
            HasWinget = $true
            HasWingetSource = $false
            Error = (($output | Out-String).Trim())
        }
    }

    $text = ($output | Out-String)
    $hasWingetSource = $text -match "(?im)^\s*winget\b"

    return [pscustomobject]@{
        HasWinget = $true
        HasWingetSource = [bool]$hasWingetSource
        Error = ""
    }
}

function Invoke-WindotsPreflight {
    [CmdletBinding()]
    param(
        [ValidateSet("install", "update", "restore")]
        [string]$Action = "install",
        [switch]$SkipNetworkChecks,
        [switch]$SkipExecutionPolicyCheck
    )

    Log-Step "Preflight checks ($Action)"

    $errors = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]

    $wingetStatus = Test-WindotsWingetSource
    if (-not $wingetStatus.HasWinget) {
        $errors.Add("winget not found. Install App Installer before continuing.")
    }
    elseif (-not $wingetStatus.HasWingetSource) {
        $errors.Add("winget source 'winget' is unavailable. Details: $($wingetStatus.Error)")
    }
    else {
        Log-Info "winget source check: OK"
    }

    if (-not $SkipExecutionPolicyCheck) {
        $policy = Get-WindotsExecutionPolicyState
        $effectivePolicy = $policy.Process
        if ($effectivePolicy -eq "Undefined") {
            $effectivePolicy = if ($policy.CurrentUser -ne "Undefined") { $policy.CurrentUser } else { $policy.LocalMachine }
        }

        if ($effectivePolicy -in @("Restricted", "AllSigned")) {
            $warnings.Add("PowerShell execution policy is '$effectivePolicy'. Prefer: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned")
        }

        Log-Info ("execution policy (Process/CurrentUser/LocalMachine): {0}/{1}/{2}" -f $policy.Process, $policy.CurrentUser, $policy.LocalMachine)
    }

    foreach ($commandName in @("git", "chezmoi", "pwsh")) {
        if (Get-Command $commandName -ErrorAction SilentlyContinue) {
            Log-Info "command detected: $commandName"
            continue
        }

        if ($Action -eq "install") {
            $warnings.Add("command not found (will be installed in INSTALL flow when applicable): $commandName")
        }
        else {
            $errors.Add("required command not found: $commandName")
        }
    }

    if (-not $SkipNetworkChecks) {
        $endpoints = @(
            [pscustomobject]@{ Url = "https://github.com"; Required = $true },
            [pscustomobject]@{ Url = "https://raw.githubusercontent.com"; Required = $true }
        )
        if ($Action -eq "install") {
            $endpoints += [pscustomobject]@{ Url = "https://windots.ilegna.dev/install"; Required = $false }
        }

        foreach ($endpoint in $endpoints) {
            $reachability = Test-WindotsHttpEndpoint -Url $endpoint.Url
            if ($reachability.Success) {
                Log-Info "connectivity check: OK ($($endpoint.Url))"
            }
            else {
                $message = "Network check failed for '$($endpoint.Url)'. $($reachability.Error)"
                if ($endpoint.Required) {
                    $errors.Add($message)
                }
                else {
                    $warnings.Add($message)
                }
            }
        }
    }

    if ($Action -in @("update", "restore")) {
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            $errors.Add("git not found in PATH.")
        }

        $chezmoiStatus = Test-WindotsChezmoiInitialized
        if (-not $chezmoiStatus.IsInitialized) {
            $errors.Add("chezmoi is not initialized. $($chezmoiStatus.Error)")
        }
        else {
            Log-Info "chezmoi source detected: $($chezmoiStatus.SourcePath)"
        }
    }

    foreach ($warning in $warnings) {
        Log-Warn $warning
    }

    if ($errors.Count -gt 0) {
        foreach ($errorMessage in $errors) {
            Log-Error $errorMessage
        }

        throw "Preflight failed with $($errors.Count) error(s)."
    }

    Log-Info "Preflight OK"
}
