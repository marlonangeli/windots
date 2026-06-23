$repoRoot = Join-Path $PSScriptRoot "..\.."
$ilegnaPath = Join-Path $repoRoot "scripts\ilegna.ps1"
$backupPath = Join-Path $repoRoot "scripts\config-backup.ps1"
$pathProfilePath = Join-Path $repoRoot "home\dot_config\powershell\profile.d\20-path.ps1"
$aiProfilePath = Join-Path $repoRoot "home\dot_config\powershell\profile.d\70-ai.ps1"
$profileWrapperPath = Join-Path $repoRoot "home\dot_config\powershell\profile.d\80-ilegna.ps1"
$opencodeRtkPluginPath = Join-Path $repoRoot "home\dot_config\opencode\plugins\rtk.ts"
$content = Get-Content -Path $ilegnaPath -Raw
$pathProfileContent = Get-Content -Path $pathProfilePath -Raw
$aiProfileContent = Get-Content -Path $aiProfilePath -Raw
$profileWrapperContent = Get-Content -Path $profileWrapperPath -Raw
$opencodeRtkPluginContent = Get-Content -Path $opencodeRtkPluginPath -Raw

Describe "ilegna command surface" {
    It "has valid PowerShell syntax" {
        foreach ($path in @($ilegnaPath, $backupPath, $pathProfilePath, $aiProfilePath, $profileWrapperPath)) {
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
        $content | Should Not Match '--time-spent'
        $pathProfileContent | Should Match 'C:\\tools\\jira-cli'
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
}
