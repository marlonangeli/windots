function Resolve-IlegnaScript {
    [CmdletBinding()]
    param()

    $candidates = New-Object System.Collections.Generic.List[string]

    if (-not [string]::IsNullOrWhiteSpace($env:ILEGNA_CLI)) {
        $candidates.Add($env:ILEGNA_CLI)
    }

    if (-not [string]::IsNullOrWhiteSpace($env:WINDOTS_REPO_ROOT)) {
        $candidates.Add((Join-Path $env:WINDOTS_REPO_ROOT "scripts\ilegna.ps1"))
    }

    if (Get-Command chezmoi -ErrorAction SilentlyContinue) {
        $sourcePath = chezmoi source-path 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($sourcePath)) {
            $candidates.Add((Join-Path $sourcePath.Trim() "scripts\ilegna.ps1"))
        }
    }

    $candidates.Add((Join-Path $HOME ".local\share\chezmoi\scripts\ilegna.ps1"))

    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path $candidate)) {
            return $candidate
        }
    }

    return $null
}

function ilegna {
    [CmdletBinding()]
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$CommandArgs)

    $scriptPath = Resolve-IlegnaScript
    if (-not $scriptPath) {
        Write-Error "ilegna CLI not found. Set ILEGNA_CLI or run from a chezmoi-managed windots source."
        return
    }

    & $scriptPath @CommandArgs
}

Set-Alias il ilegna -Force -ErrorAction SilentlyContinue
