BeforeAll {
    $repoRoot = Join-Path $PSScriptRoot "..\.."
    $windotsPath = Join-Path $repoRoot "scripts\windots.ps1"
    $content = Get-Content -Path $windotsPath -Raw
}

Describe "windots command surface" {
    It "supports restore command in dispatcher" {
        $content | Should -Match 'ValidateSet\("bootstrap",\s*"apply",\s*"update",\s*"restore",\s*"validate"\)'
    }

    It "runs chezmoi verify on apply/update workflows" {
        $content | Should -Match 'Invoke-ChezmoiVerify'
    }
}
