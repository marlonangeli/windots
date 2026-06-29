$repoRoot = Join-Path $PSScriptRoot "..\.."
$workflowPath = Join-Path $repoRoot "scripts\ilegna-workflow.ps1"
$manualPath = Join-Path $repoRoot "docs\ILEGNA.md"
$profileWrapperPath = Join-Path $repoRoot "home\dot_config\powershell\profile.d\80-ilegna.ps1"
$workflow = Get-Content -Path $workflowPath -Raw
$manual = Get-Content -Path $manualPath -Raw
$profileWrapper = Get-Content -Path $profileWrapperPath -Raw

Describe "ilegna workflow overlay" {
    It "has valid PowerShell syntax" {
        foreach ($path in @($workflowPath, $profileWrapperPath)) {
            $tokens = $null
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
            @($errors).Count | Should Be 0
        }
    }

    It "documents chezmoi, task, and git helpers" {
        $manual | Should Match 'ilegna cm capture'
        $manual | Should Match 'ilegna task start'
        $manual | Should Match 'ilegna git publish --pr'
    }

    It "dispatches new workflow resources before delegating legacy commands" {
        $workflow | Should Match 'Invoke-ChezmoiResource'
        $workflow | Should Match 'Invoke-TaskResource'
        $workflow | Should Match 'Invoke-GitResource'
        $workflow | Should Match 'Invoke-LegacyIlegna'
        $profileWrapper | Should Match 'scripts\\ilegna-workflow\.ps1'
    }

    It "keeps dry-run and local state behavior explicit" {
        $workflow | Should Match 'Dry-run complete\. No chezmoi state changed\.'
        $workflow | Should Match 'Get-TaskRoot'
        $manual | Should Match '%LOCALAPPDATA%\\ilegna\\tasks'
        $manual | Should Match 'No Jira credentials, GitHub secrets, Azure secrets, or SSH material are stored'
    }
}
