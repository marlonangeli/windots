$repoRoot = Join-Path $PSScriptRoot "..\.."
$ilegnaPath = Join-Path $repoRoot "scripts\ilegna.ps1"
$backupPath = Join-Path $repoRoot "scripts\config-backup.ps1"
$coreProfilePath = Join-Path $repoRoot "home\dot_config\powershell\profile.d\00-core.ps1"
$envProfilePath = Join-Path $repoRoot "home\dot_config\powershell\profile.d\10-env.ps1"
$pathProfilePath = Join-Path $repoRoot "home\dot_config\powershell\profile.d\20-path.ps1"
$promptProfilePath = Join-Path $repoRoot "home\dot_config\powershell\profile.d\30-prompt.ps1"
$aiProfilePath = Join-Path $repoRoot "home\dot_config\powershell\profile.d\70-ai.ps1"
$profileWrapperPath = Join-Path $repoRoot "home\dot_config\powershell\profile.d\80-ilegna.ps1"
$opencodeRtkPluginPath = Join-Path $repoRoot "home\dot_config\opencode\plugins\rtk.ts"
$content = Get-Content -Path $ilegnaPath -Raw
$coreProfileContent = Get-Content -Path $coreProfilePath -Raw
$envProfileContent = Get-Content -Path $envProfilePath -Raw
$pathProfileContent = Get-Content -Path $pathProfilePath -Raw
$promptProfileContent = Get-Content -Path $promptProfilePath -Raw
$aiProfileContent = Get-Content -Path $aiProfilePath -Raw
$profileWrapperContent = Get-Content -Path $profileWrapperPath -Raw
$opencodeRtkPluginContent = Get-Content -Path $opencodeRtkPluginPath -Raw

Describe "ilegna command surface" {
    It "has valid PowerShell syntax" {
        foreach ($path in @($ilegnaPath, $backupPath, $coreProfilePath, $envProfilePath, $pathProfilePath, $promptProfilePath, $aiProfilePath, $profileWrapperPath)) {
            $tokens = $null
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
            @($errors).Count | Should Be 0
        }
    }

    It "dispatches expected resources" {
        $content | Should Match '"wt"'
        $content | Should Match '"git-bare"'
        $content | Should Match '"pr"'
        $content | Should Match '"pipeline"'
        $content | Should Match '"jira"'
        $content | Should Match '"config"'
        $content | Should Match '"doctor"'
    }

    It "shows help for top-level and resource commands" {
        $topLevel = pwsh -NoProfile -File $ilegnaPath -h 2>&1
        $worktree = pwsh -NoProfile -File $ilegnaPath wt -h 2>&1
        $pipelines = pwsh -NoProfile -File $ilegnaPath pipelines -h 2>&1

        ($topLevel | Out-String) | Should Match 'ilegna <resource> <command>'
        ($worktree | Out-String) | Should Match 'ilegna wt <command>'
        ($pipelines | Out-String) | Should Match 'ilegna pipeline <command>'
    }

    It "supports bare repo sync refspecs" {
        $content | Should Match 'Invoke-IlegnaGitBare'
        $content | Should Match 'Sync-GitBareBranch'
        $content | Should Match '\+refs/heads/\$\{branch\}:refs/heads/\$\{branch\}'
        $content | Should Match '\+refs/tags/\*:refs/tags/\*'
    }

    It "supports interactive and bare-backed worktree creation" {
        $content | Should Match 'Read-IlegnaPrompt'
        $content | Should Match 'Read-IlegnaYesNo'
        $content | Should Match 'Get-DefaultWorktreeParent'
        $content | Should Match 'Resolve-WorktreeBaseRef'
        $content | Should Match 'FETCH_HEAD'
    }

    It "forwards raw args from the PowerShell profile wrapper" {
        $profileWrapperContent | Should Match '& \$scriptPath @args'
    }

    It "uses Azure DevOps defaults for pull requests" {
        $content | Should Match '"repos", "pr", "create"'
        $content | Should Match '-Default "develop"'
        $content | Should Match '--draft'
        $content | Should Match 'ready", "no-draft'
    }

    It "uses ankitpokhrel Jira CLI conventions" {
        $content | Should Match 'Resolve-IlegnaJiraCli'
        $content | Should Match 'C:\\tools\\jira-cli\\jira\.exe'
        $content | Should Match 'assignee = currentUser\(\)'
        $content | Should Match '"issue", "worklog", "add"'
        $content | Should Match '"--no-input"'
        $content | Should Match 'Read-IlegnaYesNo -Prompt \("Log \{0\}m to Jira issue \{1\}"'
        $content | Should Match 'Read-IlegnaJiraDuration -Prompt "Jira time spent"'
        $content | Should Match 'function ConvertTo-IlegnaJiraDuration'
        $content | Should Match '"worklog"'
        $content | Should Match '"no-log", "skip-log"'
        $content | Should Not Match '--time-spent'
        $pathProfileContent | Should Match 'C:\\tools\\jira-cli'
    }

    It "rejects invalid Jira worklog durations before calling Jira" {
        $output = pwsh -NoProfile -File $ilegnaPath jira worklog AL-1541 banana 2>&1
        ($LASTEXITCODE -ne 0) | Should Be $true
        ($output | Out-String) | Should Match "Invalid Jira duration 'banana'"
    }

    It "shows Jira timers with legacy US date strings" {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("windots-ilegna-" + [guid]::NewGuid().ToString("N"))
        $timerRoot = Join-Path $tempRoot "ilegna"
        $timerPath = Join-Path $timerRoot "work-timer.json"
        $oldLocalAppData = $env:LOCALAPPDATA

        try {
            New-Item -ItemType Directory -Path $timerRoot -Force | Out-Null
            [pscustomobject]@{
                issue = "AL-1541"
                description = "legacy timer"
                startedAt = "06/23/2020 17:04:23"
            } | ConvertTo-Json | Set-Content -Path $timerPath -Encoding UTF8

            $env:LOCALAPPDATA = $tempRoot
            $output = pwsh -NoProfile -File $ilegnaPath jira show AL-1541 2>&1
            $LASTEXITCODE | Should Be 0
            ($output | Out-String) | Should Match 'AL-1541 running for'
            ($output | Out-String) | Should Match 'legacy timer'
        }
        finally {
            $env:LOCALAPPDATA = $oldLocalAppData
            Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "stops Jira timers with a positional issue without logging" {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("windots-ilegna-" + [guid]::NewGuid().ToString("N"))
        $timerRoot = Join-Path $tempRoot "ilegna"
        $timerPath = Join-Path $timerRoot "work-timer.json"
        $oldLocalAppData = $env:LOCALAPPDATA

        try {
            New-Item -ItemType Directory -Path $timerRoot -Force | Out-Null
            [pscustomobject]@{
                issue = "AL-0000"
                description = "skip jira log"
                startedAt = (Get-Date).AddMinutes(-5).ToString("o")
            } | ConvertTo-Json | Set-Content -Path $timerPath -Encoding UTF8

            $env:LOCALAPPDATA = $tempRoot
            $output = pwsh -NoProfile -File $ilegnaPath jira stop AL-1541 --no-log 2>&1
            $LASTEXITCODE | Should Be 0
            ($output | Out-String) | Should Match 'Timer stopped for AL-1541'
            Test-Path -Path $timerPath | Should Be $false
        }
        finally {
            $env:LOCALAPPDATA = $oldLocalAppData
            Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "supports Azure pipeline discovery and triggers" {
        $content | Should Match 'Get-AzurePipelineRepositoryName'
        $content | Should Match '"pipelines", "list", "--repository"'
        $content | Should Match 'Select-AzureEnabledPipelineDefinitions'
        $content | Should Match '"pipelines", "run", "--id"'
        $content | Should Match '"approvals"'
        $content | Should Match '"complete", "approve"'
        $content | Should Match '"devops", "invoke", "--area", "release", "--resource", "approvals"'
        $content | Should Match '"statusFilter=\$statusFilter"'
    }

    It "initializes RTK for OpenCode from PowerShell" {
        $aiProfileContent | Should Match 'Initialize-RtkOpenCodeIntegration'
        $aiProfileContent | Should Match 'rtk init -g --opencode'
        $opencodeRtkPluginContent | Should Match 'rtk rewrite'
        $opencodeRtkPluginContent | Should Match 'tool\.execute\.before'
    }

    It "activates mise through WINDOTS env gates" {
        $coreProfileContent | Should Match 'function Test-WindotsEnvFlag'
        $envProfileContent | Should Match 'WINDOTS_ENABLE_MISE_ACTIVATION'
        $promptProfileContent | Should Match 'Enable-MiseActivation'
        $promptProfileContent | Should Match 'Test-WindotsEnvFlag -Name "WINDOTS_ENABLE_MISE_ACTIVATION" -Default \$true'
    }
}
