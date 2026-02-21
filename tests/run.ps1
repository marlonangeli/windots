[CmdletBinding()]
param(
    [switch]$SkipLint,
    [switch]$SkipPester,
    [switch]$SkipIntegration
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

function Invoke-Step {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Action
    )

    Write-Host "==> $Name" -ForegroundColor Cyan
    & $Action
}

function Assert-Command {
    param([Parameter(Mandatory)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

Invoke-Step -Name "Validate repository" -Action {
    & (Join-Path $repoRoot "scripts\validate.ps1")
    if ($LASTEXITCODE -ne 0) {
        throw "scripts/validate.ps1 failed with exit code $LASTEXITCODE"
    }
}

if (-not $SkipLint) {
    Invoke-Step -Name "Lint PowerShell scripts (PSScriptAnalyzer)" -Action {
        Assert-Command -Name "Invoke-ScriptAnalyzer"

        $targets = @(
            (Join-Path $repoRoot "install.ps1"),
            (Join-Path $repoRoot "init.ps1"),
            (Join-Path $repoRoot "scripts"),
            (Join-Path $repoRoot "tests")
        )

        $issues = Invoke-ScriptAnalyzer -Path $targets -Recurse
        if ($issues) {
            $issues | Format-Table -AutoSize | Out-String | Write-Host
            throw "PSScriptAnalyzer found issues."
        }
    }
}

if (-not $SkipPester) {
    Invoke-Step -Name "Run Pester tests" -Action {
        Assert-Command -Name "Invoke-Pester"

        $result = Invoke-Pester -Path (Join-Path $repoRoot "tests\pester") -PassThru
        if ($result.FailedCount -gt 0) {
            throw "Pester failed ($($result.FailedCount) failures)."
        }
    }
}

if (-not $SkipIntegration) {
    Invoke-Step -Name "Integration: chezmoi apply/verify/idempotency" -Action {
        Assert-Command -Name "chezmoi"

        chezmoi apply
        if ($LASTEXITCODE -ne 0) {
            throw "chezmoi apply failed with exit code $LASTEXITCODE"
        }

        chezmoi verify
        if ($LASTEXITCODE -ne 0) {
            throw "chezmoi verify failed with exit code $LASTEXITCODE"
        }

        chezmoi apply
        if ($LASTEXITCODE -ne 0) {
            throw "second chezmoi apply failed with exit code $LASTEXITCODE"
        }

        $diffOutput = chezmoi diff
        if ($LASTEXITCODE -ne 0) {
            throw "chezmoi diff failed with exit code $LASTEXITCODE"
        }

        $diffText = ($diffOutput | Out-String).Trim()
        if (-not [string]::IsNullOrWhiteSpace($diffText)) {
            throw "Idempotency check failed: chezmoi diff produced changes after second apply."
        }
    }
}

Write-Host "All checks passed." -ForegroundColor Green
