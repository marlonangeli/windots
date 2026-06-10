$repoRoot = Join-Path $PSScriptRoot "..\.."
$ilegnaPath = Join-Path $repoRoot "scripts\ilegna.ps1"
$backupPath = Join-Path $repoRoot "scripts\config-backup.ps1"
$pathProfilePath = Join-Path $repoRoot "home\dot_config\powershell\profile.d\20-path.ps1"
$profileWrapperPath = Join-Path $repoRoot "home\dot_config\powershell\profile.d\80-ilegna.ps1"
$content = Get-Content -Path $ilegnaPath -Raw
$pathProfileContent = Get-Content -Path $pathProfilePath -Raw
$profileWrapperContent = Get-Content -Path $profileWrapperPath -Raw

Describe "ilegna command surface" {
    It "has valid PowerShell syntax" {
        foreach ($path in @($ilegnaPath, $backupPath, $pathProfilePath, $profileWrapperPath)) {
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
}
