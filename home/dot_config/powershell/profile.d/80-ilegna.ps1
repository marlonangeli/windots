function Resolve-IlegnaScript {
    [CmdletBinding()]
    param()

    $candidates = New-Object System.Collections.Generic.List[string]

    if (Get-Command chezmoi -ErrorAction SilentlyContinue) {
        $sourcePath = chezmoi source-path 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($sourcePath)) {
            $sourceRoot = $sourcePath.Trim()
            $candidates.Add((Join-Path $sourceRoot "scripts\ilegna.ps1"))

            $sourceParent = Split-Path -Parent $sourceRoot
            if (-not [string]::IsNullOrWhiteSpace($sourceParent)) {
                $candidates.Add((Join-Path $sourceParent "scripts\ilegna.ps1"))
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($env:ILEGNA_CLI)) {
        $candidates.Add($env:ILEGNA_CLI)
    }

    if (-not [string]::IsNullOrWhiteSpace($env:WINDOTS_REPO_ROOT)) {
        $candidates.Add((Join-Path $env:WINDOTS_REPO_ROOT "scripts\ilegna.ps1"))
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
    $scriptPath = Resolve-IlegnaScript
    if (-not $scriptPath) {
        Write-Error "ilegna CLI not found. Set ILEGNA_CLI or run from a chezmoi-managed windots source."
        return
    }

    & $scriptPath @args
}

Set-Alias il ilegna -Force -ErrorAction SilentlyContinue
