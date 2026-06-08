$repoRoot = Join-Path $PSScriptRoot "..\.."
. (Join-Path $repoRoot "modules\module-registry.ps1")

Describe "Windots default module profiles" {
    It "returns defaults for full mode" {
        $defaults = Get-WindotsDefaultModules -Mode full
        ($defaults -contains "core") | Should Be $true
        ($defaults -contains "packages") | Should Be $true
        ($defaults -contains "shell") | Should Be $true
        ($defaults -contains "development") | Should Be $true
    }

    It "returns defaults for clean mode" {
        $defaults = Get-WindotsDefaultModules -Mode clean
        ($defaults -contains "core") | Should Be $true
        ($defaults -contains "terminal") | Should Be $true
    }
}
