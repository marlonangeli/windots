BeforeAll {
    $repoRoot = Join-Path $PSScriptRoot "..\.."
    . (Join-Path $repoRoot "modules\module-registry.ps1")
}

Describe "Windots module registry" {
    It "is structurally valid" {
        $result = Test-WindotsModuleRegistry -ScriptsRoot $repoRoot
        $result.IsValid | Should -BeTrue
    }

    It "resolves full mode with core first" {
        $plan = Resolve-WindotsModuleExecutionPlan -Mode full -ScriptsRoot $repoRoot
        $plan[0].Name | Should -Be "core"
        ($plan | Select-Object -ExpandProperty Name) | Should -Contain "development"
    }

    It "injects dependencies for explicit module selection" {
        $plan = Resolve-WindotsModuleExecutionPlan -Mode full -RequestedModules @("mise") -ScriptsRoot $repoRoot
        $names = $plan | Select-Object -ExpandProperty Name
        $names | Should -Contain "core"
        $names | Should -Contain "mise"
    }

    It "fails on unknown module names" {
        {
            Resolve-WindotsModuleExecutionPlan -Mode full -RequestedModules @("does-not-exist") -ScriptsRoot $repoRoot
        } | Should -Throw
    }
}
