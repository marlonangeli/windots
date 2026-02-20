# ============================================
# Utility Functions
# ============================================

# File Operations
function la {
    Enable-TerminalIcons
    if (Get-Command Format-TerminalIcons -ErrorAction SilentlyContinue) {
        Get-ChildItem -Force @args | Format-TerminalIcons
        return
    }
    Get-ChildItem -Force @args
}
function ll {
    Enable-TerminalIcons
    if (Get-Command Format-TerminalIcons -ErrorAction SilentlyContinue) {
        Get-ChildItem @args | Format-TerminalIcons
        return
    }
    Get-ChildItem @args
}
function which($cmd) { (Get-Command $cmd -ErrorAction SilentlyContinue).Source }
function touch($f) { New-Item -ItemType File -Path $f -Force | Out-Null }
function mkcd($d) { New-Item -ItemType Directory -Path $d -Force | Out-Null; Set-Location $d }
function take($d) { mkcd $d }

# Profile Management
function reload { . $PROFILE }
function ep { zed $PROFILE }
function pclean { Set-ProfileMode clean }
function pfull { Set-ProfileMode full }
function pmode { Get-ProfileMode }

# Editor Shortcuts
function z-edit { zed @args }
function c-edit { code @args }
function vs { devenv @args }
function rider { rider64.exe @args }
Set-Alias edit zed -Force -ErrorAction SilentlyContinue
function c { code . @args }

# Sophos
function sop {
    if (-not (Get-Module BWSecret)) {
        Import-Module "$PSScriptRoot\..\Modules\BWSecret\1.0.0\BWSecret.psm1" -ErrorAction SilentlyContinue
    }
    Get-SophosPassword
}

# Azure DevOps
if (Get-Command az -ErrorAction SilentlyContinue) {
    function az-repos { az repos list --output table }
    function az-pipe { az pipelines list --output table }
}

# Jira
if (Get-Command jira -ErrorAction SilentlyContinue) {
    function jira-my {
        $me = jira me 2>$null
        if (-not $me) {
            Write-Warning "Unable to resolve current Jira user. Run: jira init"
            return
        }
        jira issue list --assignee $me @args
    }
}
