BeforeAll {
    $scriptsRoot = Join-Path $PSScriptRoot "..\..\scripts"
    . (Join-Path $scriptsRoot "modules\module-registry.ps1")
}

Describe "Windots module registry" {
    It "is structurally valid" {
        $result = Test-WindotsModuleRegistry -ScriptsRoot $scriptsRoot
        $result.IsValid | Should -BeTrue
    }

    It "resolves full mode with core first" {
        $plan = Resolve-WindotsModuleExecutionPlan -Mode full -ScriptsRoot $scriptsRoot
        $plan[0].Name | Should -Be "core"
    }

    It "injects dependencies for explicit module selection" {
        $plan = Resolve-WindotsModuleExecutionPlan -Mode full -RequestedModules @("mise") -ScriptsRoot $scriptsRoot
        $names = $plan | Select-Object -ExpandProperty Name
        $names | Should -Contain "core"
        $names | Should -Contain "packages"
        $names | Should -Contain "mise"
    }

    It "fails on unknown module names" {
        {
            Resolve-WindotsModuleExecutionPlan -Mode full -RequestedModules @("does-not-exist") -ScriptsRoot $scriptsRoot
        } | Should -Throw
    }
}
