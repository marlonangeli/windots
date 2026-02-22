BeforeAll {
    $repoRoot = Join-Path $PSScriptRoot "..\.."
    . (Join-Path $repoRoot "modules\module-registry.ps1")
}

Describe "Windots default module profiles" {
    It "returns defaults for full mode" {
        $defaults = Get-WindotsDefaultModules -Mode full
        $defaults | Should -Contain "core"
        $defaults | Should -Contain "packages"
        $defaults | Should -Contain "shell"
        $defaults | Should -Contain "development"
    }

    It "returns defaults for clean mode" {
        $defaults = Get-WindotsDefaultModules -Mode clean
        $defaults | Should -Contain "core"
        $defaults | Should -Contain "terminal"
    }
}
