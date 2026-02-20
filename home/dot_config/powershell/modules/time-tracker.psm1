# ============================================
# Time Tracking with Jira Integration
# PowerShell approved verbs and interactive
# ============================================

$global:__TimeTracker = @{
    Start = $null
    IssueKey = $null
    Description = $null
    PausedAt = $null
    PausedDuration = [timespan]::Zero
}

function Get-TrackedDuration {
    [CmdletBinding()]
    [OutputType([timespan])]
    param()

    if ($null -eq $global:__TimeTracker.Start) {
        return [timespan]::Zero
    }

    $endPoint = if ($global:__TimeTracker.PausedAt) { $global:__TimeTracker.PausedAt } else { Get-Date }
    $raw = $endPoint - $global:__TimeTracker.Start
    return $raw - $global:__TimeTracker.PausedDuration
}

function Clear-TimeTracker {
    [CmdletBinding()]
    param()

    $global:__TimeTracker.Start = $null
    $global:__TimeTracker.IssueKey = $null
    $global:__TimeTracker.Description = $null
    $global:__TimeTracker.PausedAt = $null
    $global:__TimeTracker.PausedDuration = [timespan]::Zero
}

function Start-Work {
    <#
    .SYNOPSIS
        Starts a work timer for time tracking.

    .DESCRIPTION
        Begins tracking time for a task or Jira issue.
        Can track time without Jira integration or with an issue key for automatic logging.

    .PARAMETER IssueKey
        Jira issue key (e.g., AL-1234). Optional - prompts if not provided.

    .PARAMETER Description
        Description of the work being done

    .PARAMETER NoPrompt
        Skip interactive prompts

    .EXAMPLE
        Start-Work -IssueKey "AL-1234" -Description "Implementing authentication"
        Starts timer with Jira issue

    .EXAMPLE
        Start-Work
        Interactive mode - prompts for issue key and description

    .EXAMPLE
        Start-Work -NoPrompt
        Starts timer without any metadata

    .LINK
        Stop-Work
        Show-Work
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$IssueKey,

        [Parameter(Mandatory=$false)]
        [string]$Description = "",

        [Parameter(Mandatory=$false)]
        [switch]$NoPrompt
    )

    if ($global:__TimeTracker.Start) {
        Write-Warning "A timer is already active. Run Stop-Work or Pause-Work before starting another."
        return
    }

    # Interactive mode
    if (-not $NoPrompt -and -not $IssueKey) {
        Write-Host "`n⏱️  Start Work Timer" -ForegroundColor Cyan
        Write-Host "=" * 40 -ForegroundColor Cyan

        $IssueKey = Read-Host "`nJira issue key (e.g., AL-1234, or press Enter to skip)"

        if ($IssueKey) {
            # Validate issue key format
            if ($IssueKey -notmatch '^[A-Z]+-\d+$') {
                Write-Warning "Invalid issue key format. Expected: PROJECT-123"
                $confirm = Read-Host "Continue anyway? (y/n)"
                if ($confirm -ne 'y') { return }
            }
        }

        if (-not $Description) {
            $Description = Read-Host "Description (optional)"
        }
    }

    $global:__TimeTracker.Start = Get-Date
    $global:__TimeTracker.IssueKey = $IssueKey
    $global:__TimeTracker.Description = $Description
    $global:__TimeTracker.PausedAt = $null
    $global:__TimeTracker.PausedDuration = [timespan]::Zero

    Write-Host "`n⏱️  Timer started: $($global:__TimeTracker.Start.ToString('HH:mm:ss'))" -ForegroundColor Green
    if ($IssueKey) {
        Write-Host "📋 Issue: $IssueKey" -ForegroundColor Cyan
    }
    if ($Description) {
        Write-Host "📝 Description: $Description" -ForegroundColor Yellow
    }
    Write-Host ""
}

function Stop-Work {
    <#
    .SYNOPSIS
        Stops the work timer and optionally logs to Jira.

    .DESCRIPTION
        Stops the active timer, calculates elapsed time, and can automatically
        log the time to Jira using the Jira CLI.

    .PARAMETER IssueKey
        Jira issue key. If not provided, uses the key from Start-Work.

    .PARAMETER Comment
        Comment to add to the Jira worklog

    .PARAMETER NoLog
        Stop timer without logging to Jira

    .PARAMETER Force
        Skip confirmation prompt before logging to Jira

    .EXAMPLE
        Stop-Work
        Stops timer and prompts for Jira logging if issue key exists

    .EXAMPLE
        Stop-Work -IssueKey "AL-1234" -Comment "Completed authentication"
        Stops and logs to specific issue

    .EXAMPLE
        Stop-Work -NoLog
        Stops timer without Jira logging

    .LINK
        Start-Work
        Show-Work
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$IssueKey,

        [Parameter(Mandatory=$false)]
        [string]$Comment,

        [Parameter(Mandatory=$false)]
        [switch]$NoLog,

        [Parameter(Mandatory=$false)]
        [switch]$Force
    )

    if ($null -eq $global:__TimeTracker.Start) {
        Write-Warning "No timer active. Start one with: Start-Work"
        return
    }

    if ($global:__TimeTracker.PausedAt) {
        Write-Warning "Timer is paused. Use Resume-Work before stopping if you want to continue counting."
    }

    $duration = Get-TrackedDuration
    $hours = [math]::Floor($duration.TotalHours)
    $minutes = $duration.Minutes

    # Formatar para Jira: Xh Ym
    $timeSpent = ""
    if ($hours -gt 0) { $timeSpent += "${hours}h " }
    if ($minutes -gt 0) { $timeSpent += "${minutes}m" }
    $timeSpent = $timeSpent.Trim()

    Write-Host "`n⏱️  Time elapsed: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
    Write-Host "📊 Jira format: $timeSpent" -ForegroundColor Magenta

    # Usar IssueKey do timer se não foi especificado
    if (-not $IssueKey -and $global:__TimeTracker.IssueKey) {
        $IssueKey = $global:__TimeTracker.IssueKey
    }

    # Log no Jira
    if ($duration.TotalHours -gt 12 -and -not $Force) {
        $confirmLongSession = Read-Host "Timer has more than 12h. Continue with this duration? (y/n) [default: n]"
        if ($confirmLongSession -ne "y") {
            Write-Host "❌ Stop cancelled" -ForegroundColor Yellow
            return
        }
    }

    if ($IssueKey -and -not $NoLog) {
        # Verificar se Jira CLI está instalado
        if (-not (Get-Command jira -ErrorAction SilentlyContinue)) {
            Write-Warning "Jira CLI not found. Install from: https://github.com/ankitpokhrel/jira-cli"
            Write-Host "💡 Time not logged. Install Jira CLI and try: Stop-Work -IssueKey $IssueKey" -ForegroundColor Yellow
        } else {
            # Confirmação antes de logar (exceto se Force)
            if (-not $Force) {
                Write-Host "`n📤 Ready to log worklog to Jira:" -ForegroundColor Yellow
                Write-Host "   Issue: $IssueKey" -ForegroundColor Yellow
                Write-Host "   Time: $timeSpent" -ForegroundColor Yellow
                if ($Comment -or $global:__TimeTracker.Description) {
                    $logComment = if ($Comment) { $Comment } else { $global:__TimeTracker.Description }
                    Write-Host "   Comment: $logComment" -ForegroundColor Yellow
                }

                $confirm = Read-Host "`nLog to Jira? (y/n) [default: y]"
                if ($confirm -and $confirm -ne 'y') {
                    Write-Host "❌ Worklog not logged" -ForegroundColor Yellow
                    Clear-TimeTracker
                    return
                }
            }

            # Preparar comment
            $commentArg = ""
            $logComment = if ($Comment) { $Comment } elseif ($global:__TimeTracker.Description) { $global:__TimeTracker.Description } else { "" }

            if ($logComment) {
                $commentArg = "--comment `"$logComment`""
            }

            Write-Host "`n📤 Logging to Jira: $IssueKey ($timeSpent)" -ForegroundColor Cyan

            try {
                $cmd = "jira issue worklog add $IssueKey `"$timeSpent`" $commentArg --no-input"
                Invoke-Expression $cmd

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✅ Worklog added to $IssueKey" -ForegroundColor Green
                } else {
                    Write-Host "❌ Failed to add worklog. Check Jira CLI configuration." -ForegroundColor Red
                    Write-Host "💡 Run: jira init" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Error "Error logging to Jira: $_"
            }
        }
    } elseif (-not $IssueKey) {
        Write-Host "`n💡 To log time to Jira, use: Stop-Work -IssueKey AL-XXX" -ForegroundColor Yellow
    }

    Clear-TimeTracker

    Write-Host ""
}

function Show-Work {
    <#
    .SYNOPSIS
        Shows current timer status without stopping it.

    .DESCRIPTION
        Displays the elapsed time of the active work timer along with
        associated issue key and description if available.

    .EXAMPLE
        Show-Work
        Displays current timer information

    .LINK
        Start-Work
        Stop-Work
    #>
    [CmdletBinding()]
    param()

    if ($null -eq $global:__TimeTracker.Start) {
        Write-Host "`n⚠️  No timer active" -ForegroundColor Yellow
        Write-Host "💡 Start one with: Start-Work" -ForegroundColor Cyan
        Write-Host ""
        return
    }

    $duration = Get-TrackedDuration
    $hours = [math]::Floor($duration.TotalHours)
    $minutes = $duration.Minutes

    Write-Host "`n⏱️  Current Time: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
    Write-Host "🕐 Started: $($global:__TimeTracker.Start.ToString('HH:mm:ss'))" -ForegroundColor Yellow

    if ($global:__TimeTracker.IssueKey) {
        Write-Host "📋 Issue: $($global:__TimeTracker.IssueKey)" -ForegroundColor Green
    }
    if ($global:__TimeTracker.Description) {
        Write-Host "📝 Description: $($global:__TimeTracker.Description)" -ForegroundColor Yellow
    }
    if ($global:__TimeTracker.PausedAt) {
        Write-Host "⏸️  Status: paused" -ForegroundColor DarkYellow
    }

    $timeSpent = ""
    if ($hours -gt 0) { $timeSpent += "${hours}h " }
    if ($minutes -gt 0) { $timeSpent += "${minutes}m" }
    Write-Host "📊 Jira format: $($timeSpent.Trim())" -ForegroundColor Magenta
    Write-Host ""
}

function Reset-Work {
    <#
    .SYNOPSIS
        Resets the timer without logging.

    .DESCRIPTION
        Clears the current work timer and all associated metadata
        without logging to Jira.

    .EXAMPLE
        Reset-Work
        Resets the timer

    .LINK
        Start-Work
        Stop-Work
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($null -eq $global:__TimeTracker.Start) {
        Write-Host "⚠️  No timer active" -ForegroundColor Yellow
        return
    }

    if ($PSCmdlet.ShouldProcess("Current timer", "Reset")) {
        Clear-TimeTracker
        Write-Host "♻️  Timer reset" -ForegroundColor Green
    }
}

function Pause-Work {
    [CmdletBinding()]
    param()

    if (-not $global:__TimeTracker.Start) {
        Write-Warning "No timer active."
        return
    }
    if ($global:__TimeTracker.PausedAt) {
        Write-Warning "Timer is already paused."
        return
    }

    $global:__TimeTracker.PausedAt = Get-Date
    Write-Host "⏸️  Timer paused at $($global:__TimeTracker.PausedAt.ToString('HH:mm:ss'))" -ForegroundColor Yellow
}

function Resume-Work {
    [CmdletBinding()]
    param()

    if (-not $global:__TimeTracker.Start) {
        Write-Warning "No timer active."
        return
    }
    if (-not $global:__TimeTracker.PausedAt) {
        Write-Warning "Timer is not paused."
        return
    }

    $pauseSpan = (Get-Date) - $global:__TimeTracker.PausedAt
    $global:__TimeTracker.PausedDuration += $pauseSpan
    $global:__TimeTracker.PausedAt = $null
    Write-Host "▶️  Timer resumed" -ForegroundColor Green
}

# Aliases (mantém compatibilidade)
Set-Alias work-start Start-Work -Force -ErrorAction SilentlyContinue
Set-Alias work-stop Stop-Work -Force -ErrorAction SilentlyContinue
Set-Alias work-show Show-Work -Force -ErrorAction SilentlyContinue
Set-Alias ws Start-Work -Force -ErrorAction SilentlyContinue
Set-Alias we Stop-Work -Force -ErrorAction SilentlyContinue
Set-Alias wt Show-Work -Force -ErrorAction SilentlyContinue
Set-Alias wp Pause-Work -Force -ErrorAction SilentlyContinue
Set-Alias wr Resume-Work -Force -ErrorAction SilentlyContinue

# Export functions
Export-ModuleMember -Function Start-Work, Stop-Work, Show-Work, Reset-Work, Pause-Work, Resume-Work -Alias *
