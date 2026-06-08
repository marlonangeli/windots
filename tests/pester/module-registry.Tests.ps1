$repoRoot = Join-Path $PSScriptRoot "..\.."
. (Join-Path $repoRoot "modules\module-registry.ps1")

Describe "Windots module registry" {
    It "is structurally valid" {
        $result = Test-WindotsModuleRegistry -ScriptsRoot $repoRoot
        $result.IsValid | Should Be $true
    }

    It "resolves full mode with core first" {
        $plan = Resolve-WindotsModuleExecutionPlan -Mode full -ScriptsRoot $repoRoot
        $plan[0].Name | Should Be "core"
        $names = $plan | Select-Object -ExpandProperty Name
        ($names -contains "development") | Should Be $true
    }

    It "injects dependencies for explicit module selection" {
        $plan = Resolve-WindotsModuleExecutionPlan -Mode full -RequestedModules @("mise") -ScriptsRoot $repoRoot
        $names = $plan | Select-Object -ExpandProperty Name
        ($names -contains "core") | Should Be $true
        ($names -contains "mise") | Should Be $true
    }

    It "fails on unknown module names" {
        $threw = $false
        try {
            Resolve-WindotsModuleExecutionPlan -Mode full -RequestedModules @("does-not-exist") -ScriptsRoot $repoRoot
        }
        catch {
            $threw = $true
        }

        $threw | Should Be $true
    }
}
