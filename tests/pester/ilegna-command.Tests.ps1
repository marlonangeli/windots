$repoRoot = Join-Path $PSScriptRoot "..\.."
$ilegnaPath = Join-Path $repoRoot "scripts\ilegna.ps1"
$backupPath = Join-Path $repoRoot "scripts\config-backup.ps1"
$content = Get-Content -Path $ilegnaPath -Raw

Describe "ilegna command surface" {
    It "has valid PowerShell syntax" {
        foreach ($path in @($ilegnaPath, $backupPath)) {
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
}
