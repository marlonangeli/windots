function cx { codex @args }

function Initialize-RtkOpenCodeIntegration {
    if (-not (Get-Command rtk -ErrorAction SilentlyContinue)) { return }

    $pluginPath = Join-Path $HOME ".config\opencode\plugins\rtk.ts"
    if (Test-Path -LiteralPath $pluginPath) { return }

    rtk init -g --opencode *> $null
    if ($LASTEXITCODE -ne 0 -and $env:WINDOTS_PROFILE_DEBUG) {
        Write-Warning "Unable to initialize RTK OpenCode integration."
    }
}

function oc {
    Initialize-RtkOpenCodeIntegration

    if (Get-Command opencode -ErrorAction SilentlyContinue) {
        opencode @args
        return
    }

    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        wsl opencode @args
        return
    }

    Write-Warning "opencode not found. Install it with mise or run it from WSL."
}

function ai-home { Set-Location (Join-Path $HOME ".config\ai") }
