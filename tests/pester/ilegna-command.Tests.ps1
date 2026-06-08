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
        $content | Should Match '"pr"'
        $content | Should Match '"pipeline"'
        $content | Should Match '"jira"'
        $content | Should Match '"config"'
        $content | Should Match '"doctor"'
    }
}
