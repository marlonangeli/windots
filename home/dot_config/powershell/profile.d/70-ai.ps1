function cx { codex @args }

function oc {
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
