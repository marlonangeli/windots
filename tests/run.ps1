[CmdletBinding()]
param(
    [switch]$SkipLint,
    [switch]$SkipPester,
    [switch]$SkipIntegration,
    [switch]$IncludeIntegration
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
    if (-not $?) {
        throw "scripts/validate.ps1 failed"
    }
}

if (-not $SkipLint) {
    Invoke-Step -Name "Lint PowerShell scripts (PSScriptAnalyzer)" -Action {
        if (-not (Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue)) {
            Write-Warning "Skipping lint step: Invoke-ScriptAnalyzer not found. Install PSScriptAnalyzer or run with -SkipLint."
            return
        }

        & (Join-Path $repoRoot "scripts\lint.ps1")
        if (-not $?) {
            throw "scripts/lint.ps1 failed"
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

if ($IncludeIntegration -and -not $SkipIntegration) {
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
else {
    Write-Host "==> Integration skipped (use -IncludeIntegration to run chezmoi apply/verify/idempotency)" -ForegroundColor DarkGray
}

Write-Host "All checks passed." -ForegroundColor Green
