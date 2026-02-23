[CmdletBinding()]
param()

function Get-WindotsModuleRegistry {
    [CmdletBinding()]
    param(
        [string]$ScriptsRoot = (Split-Path -Parent $PSScriptRoot)
    )

    return @(
        [pscustomobject]@{
            Name = "core"
            DisplayName = "Core"
            Description = "Installs required base tooling and applies chezmoi state."
            DependsOn = @()
            Category = "action"
            RequiresElevation = $false
            Optional = $false
            Modes = @("full", "clean")
            ScriptPath = (Join-Path $ScriptsRoot "modules\core\module.ps1")
            EntryFunction = "Invoke-WindotsModuleCore"
        },
        [pscustomobject]@{
            Name = "packages"
            DisplayName = "Packages"
            Description = "Installs optional package bundle for developer workflows."
            DependsOn = @("core")
            Category = "action"
            RequiresElevation = $false
            Optional = $true
            Modes = @("full", "clean")
            ScriptPath = (Join-Path $ScriptsRoot "modules\packages\module.ps1")
            EntryFunction = "Invoke-WindotsModulePackages"
        },
        [pscustomobject]@{
            Name = "shell"
            DisplayName = "Shell"
            Description = "Configures PowerShell profile, helpers, and shell experience."
            DependsOn = @("core")
            Category = "action"
            RequiresElevation = $false
            Optional = $false
            Modes = @("full", "clean")
            ScriptPath = (Join-Path $ScriptsRoot "modules\shell\module.ps1")
            EntryFunction = "Invoke-WindotsModuleShell"
        },
        [pscustomobject]@{
            Name = "development"
            DisplayName = "Development"
            Description = "Installs optional dev runtimes and CLI tooling."
            DependsOn = @("core", "packages", "mise")
            Category = "action"
            RequiresElevation = $false
            Optional = $true
            Modes = @("full", "clean")
            ScriptPath = (Join-Path $ScriptsRoot "modules\development\module.ps1")
            EntryFunction = "Invoke-WindotsModuleDevelopment"
        },
        [pscustomobject]@{
            Name = "themes"
            DisplayName = "Themes"
            Description = "Sets fonts and prompt theme defaults across terminal tools."
            DependsOn = @("shell")
            Category = "action"
            RequiresElevation = $false
            Optional = $true
            Modes = @("full", "clean")
            ScriptPath = (Join-Path $ScriptsRoot "modules\themes\module.ps1")
            EntryFunction = "Invoke-WindotsModuleThemes"
        },
        [pscustomobject]@{
            Name = "terminal"
            DisplayName = "Terminal"
            Description = "Ensures Windows Terminal templates and sync hooks are ready."
            DependsOn = @("core")
            Category = "config"
            RequiresElevation = $false
            Optional = $false
            Modes = @("full", "clean")
            ScriptPath = (Join-Path $ScriptsRoot "modules\terminal\module.ps1")
            EntryFunction = "Invoke-WindotsModuleTerminal"
        },
        [pscustomobject]@{
            Name = "ai"
            DisplayName = "AI"
            Description = "Installs AI tooling and syncs MCP and skills configs."
            DependsOn = @("core")
            Category = "action"
            RequiresElevation = $false
            Optional = $true
            Modes = @("full", "clean")
            ScriptPath = (Join-Path $ScriptsRoot "modules\ai\module.ps1")
            EntryFunction = "Invoke-WindotsModuleAI"
        },
        [pscustomobject]@{
            Name = "mise"
            DisplayName = "Mise"
            Description = "Configures mise, trusts config, and installs toolchain versions."
            DependsOn = @("core")
            Category = "action"
            RequiresElevation = $false
            Optional = $true
            Modes = @("full", "clean")
            ScriptPath = (Join-Path $ScriptsRoot "modules\mise\module.ps1")
            EntryFunction = "Invoke-WindotsModuleMise"
        },
        [pscustomobject]@{
            Name = "secrets"
            DisplayName = "Secrets"
            Description = "Validates secret tooling and checks external secret dependencies."
            DependsOn = @("core")
            Category = "action"
            RequiresElevation = $false
            Optional = $true
            Modes = @("full", "clean")
            ScriptPath = (Join-Path $ScriptsRoot "modules\secrets\module.ps1")
            EntryFunction = "Invoke-WindotsModuleSecrets"
        },
        [pscustomobject]@{
            Name = "validate"
            DisplayName = "Validate"
            Description = "Runs repository validation checks and policy guardrails."
            DependsOn = @("core")
            Category = "action"
            RequiresElevation = $false
            Optional = $true
            Modes = @("full", "clean")
            ScriptPath = (Join-Path $ScriptsRoot "modules\validate\module.ps1")
            EntryFunction = "Invoke-WindotsModuleValidate"
        }
    )
}

function Get-WindotsDefaultModules {
    [CmdletBinding()]
    param(
        [ValidateSet("full", "clean")]
        [string]$Mode = "full"
    )

    switch ($Mode) {
        "full" {
            return @("core", "shell", "mise", "packages", "development", "themes", "terminal", "ai")
        }
        "clean" {
            return @("core", "shell", "packages", "themes", "terminal")
        }
        default {
            throw "Unsupported mode: $Mode"
        }
    }
}

function Resolve-WindotsModuleExecutionPlan {
    [CmdletBinding()]
    param(
        [ValidateSet("full", "clean")]
        [string]$Mode = "full",
        [string[]]$RequestedModules,
        [string]$ScriptsRoot = (Split-Path -Parent $PSScriptRoot)
    )

    $registry = Get-WindotsModuleRegistry -ScriptsRoot $ScriptsRoot
    $byName = @{}
    foreach ($module in $registry) {
        $key = $module.Name.ToLowerInvariant()
        if ($byName.ContainsKey($key)) {
            throw "Duplicate module name in registry: $($module.Name)"
        }
        $byName[$key] = $module
    }

    $requested = if ($RequestedModules -and $RequestedModules.Count -gt 0) {
        @($RequestedModules)
    }
    else {
        Get-WindotsDefaultModules -Mode $Mode
    }

    $normalized = @(
        $requested |
            ForEach-Object { $_.ToString().Trim().ToLowerInvariant() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )

    if (-not $normalized -or $normalized.Count -eq 0) {
        return @()
    }

    $expanded = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    function Add-ModuleWithDependencies {
        param([Parameter(Mandatory)][string]$ModuleName)

        if (-not $byName.ContainsKey($ModuleName)) {
            throw "Unknown module requested: $ModuleName"
        }

        if ($expanded.Contains($ModuleName)) {
            return
        }

        $null = $expanded.Add($ModuleName)
        foreach ($dep in $byName[$ModuleName].DependsOn) {
            Add-ModuleWithDependencies -ModuleName $dep.ToLowerInvariant()
        }
    }

    foreach ($name in $normalized) {
        Add-ModuleWithDependencies -ModuleName $name
    }

    $visitState = @{}
    $orderedNames = New-Object System.Collections.Generic.List[string]

    function Visit-Module {
        param([Parameter(Mandatory)][string]$ModuleName)

        $state = if ($visitState.ContainsKey($ModuleName)) { $visitState[$ModuleName] } else { 0 }
        if ($state -eq 2) { return }
        if ($state -eq 1) {
            throw "Cyclic module dependency detected at '$ModuleName'"
        }

        $visitState[$ModuleName] = 1
        foreach ($dep in $byName[$ModuleName].DependsOn) {
            $depKey = $dep.ToLowerInvariant()
            if ($expanded.Contains($depKey)) {
                Visit-Module -ModuleName $depKey
            }
        }

        $visitState[$ModuleName] = 2
        if (-not $orderedNames.Contains($ModuleName)) {
            $null = $orderedNames.Add($ModuleName)
        }
    }

    foreach ($name in $normalized) {
        Visit-Module -ModuleName $name
    }

    $plan = @()
    foreach ($moduleName in $orderedNames) {
        $module = $byName[$moduleName]
        if ($module.Modes -and $module.Modes.Count -gt 0 -and $Mode -notin $module.Modes) {
            throw "Module '$($module.Name)' is not available in mode '$Mode'"
        }
        $plan += $module
    }

    return $plan
}

function Test-WindotsModuleRegistry {
    [CmdletBinding()]
    param(
        [string]$ScriptsRoot = (Split-Path -Parent $PSScriptRoot)
    )

    $errors = New-Object System.Collections.Generic.List[string]
    $registry = @()

    try {
        $registry = Get-WindotsModuleRegistry -ScriptsRoot $ScriptsRoot
    }
    catch {
        $errors.Add("Failed to load module registry: $($_.Exception.Message)")
        return [pscustomobject]@{
            IsValid = $false
            Errors = @($errors)
            Modules = @()
        }
    }

    $byName = @{}
    foreach ($module in $registry) {
        $key = $module.Name.ToLowerInvariant()
        if ($byName.ContainsKey($key)) {
            $errors.Add("Duplicate module name: $($module.Name)")
            continue
        }
        $byName[$key] = $module

        if (-not (Test-Path $module.ScriptPath)) {
            $errors.Add("Missing module script for '$($module.Name)': $($module.ScriptPath)")
        }

        if ([string]::IsNullOrWhiteSpace($module.EntryFunction)) {
            $errors.Add("Missing entry function for module '$($module.Name)'")
        }
    }

    foreach ($module in $registry) {
        foreach ($dependency in $module.DependsOn) {
            $depKey = $dependency.ToString().Trim().ToLowerInvariant()
            if (-not $byName.ContainsKey($depKey)) {
                $errors.Add("Module '$($module.Name)' depends on unknown module '$depKey'")
            }
        }
    }

    foreach ($mode in @("full", "clean")) {
        try {
            $null = Resolve-WindotsModuleExecutionPlan -Mode $mode -ScriptsRoot $ScriptsRoot
        }
        catch {
            $errors.Add("Execution plan failed for mode '$mode': $($_.Exception.Message)")
        }
    }

    return [pscustomobject]@{
        IsValid = ($errors.Count -eq 0)
        Errors = @($errors)
        Modules = $registry
    }
}
