BeforeAll {
    $scriptsRoot = Join-Path $PSScriptRoot "..\..\scripts"
    . (Join-Path $scriptsRoot "modules\module-registry.ps1")
}

Describe "Windots default module profiles" {
    It "returns defaults for full mode" {
        $defaults = Get-WindotsDefaultModules -Mode full
        $defaults | Should -Contain "core"
        $defaults | Should -Contain "packages"
        $defaults | Should -Contain "shell"
    }

    It "returns defaults for clean mode" {
        $defaults = Get-WindotsDefaultModules -Mode clean
        $defaults | Should -Contain "core"
        $defaults | Should -Contain "terminal"
    }
}
