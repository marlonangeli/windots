[CmdletBinding()]
param()

$script:WindotsPackageRepoCache = $null

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $repoRoot "scripts\common\logging.ps1")
. (Join-Path $PSScriptRoot "provider-winget.ps1")
. (Join-Path $PSScriptRoot "provider-mise.ps1")

function Get-WindotsPackageRepository {
    [CmdletBinding()]
    param(
        [string]$Path = (Join-Path $PSScriptRoot "repository.psd1"),
        [switch]$ForceReload
    )

    if (-not $ForceReload -and $script:WindotsPackageRepoCache) {
        return $script:WindotsPackageRepoCache
    }

    if (-not (Test-Path $Path)) {
        throw "Package repository manifest not found: $Path"
    }

    $repo = Import-PowerShellDataFile -Path $Path
    if (-not $repo.Packages) {
        throw "Invalid package repository manifest: Packages is required"
    }

    $script:WindotsPackageRepoCache = $repo
    return $repo
}

function Test-WindotsPackageManifest {
    [CmdletBinding()]
    param(
        [string]$Path = (Join-Path $PSScriptRoot "repository.psd1")
    )

    $errors = New-Object System.Collections.Generic.List[string]

    try {
        $repo = Get-WindotsPackageRepository -Path $Path -ForceReload
    }
    catch {
        $errors.Add($_.Exception.Message)
        return [pscustomobject]@{ IsValid = $false; Errors = @($errors) }
    }

    $names = @{}
    foreach ($pkg in $repo.Packages) {
        foreach ($field in @('Name', 'Provider', 'PackageId', 'Modules', 'Modes', 'Required')) {
            if (-not $pkg.ContainsKey($field)) {
                $errors.Add("Package missing required field '$field': $($pkg | Out-String)")
            }
        }

        if ($pkg.Name -and $names.ContainsKey($pkg.Name.ToLowerInvariant())) {
            $errors.Add("Duplicate package name: $($pkg.Name)")
        }
        elseif ($pkg.Name) {
            $names[$pkg.Name.ToLowerInvariant()] = $true
        }

        if ($pkg.Provider -and $pkg.Provider -notin @('winget', 'mise')) {
            $errors.Add("Unsupported provider '$($pkg.Provider)' in package '$($pkg.Name)'")
        }

        foreach ($mode in @($pkg.Modes)) {
            if ($mode -notin @('full', 'clean')) {
                $errors.Add("Unsupported mode '$mode' in package '$($pkg.Name)'")
            }
        }
    }

    return [pscustomobject]@{ IsValid = ($errors.Count -eq 0); Errors = @($errors) }
}

function Get-WindotsModulePackages {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Module,
        [ValidateSet('full', 'clean')][string]$Mode = 'full'
    )

    $repo = Get-WindotsPackageRepository
    return @(
        $repo.Packages | Where-Object {
            $pkgModules = @($_.Modules)
            $pkgModes = @($_.Modes)
            $pkgModules -contains $Module -and $pkgModes -contains $Mode
        }
    )
}

function Test-WindotsGumAvailable {
    [CmdletBinding()]
    param()

    return ($null -ne (Get-Command gum -ErrorAction SilentlyContinue))
}

function Resolve-WindotsPackageSelection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Module,
        [Parameter(Mandatory)][hashtable[]]$Packages,
        [switch]$NoPrompt
    )

    if (-not $Packages -or $Packages.Count -eq 0) {
        return @()
    }

    $requiredNames = @($Packages | Where-Object { $_.Required } | ForEach-Object { $_.Name })
    $optionalNames = @($Packages | Where-Object { -not $_.Required } | ForEach-Object { $_.Name })

    if ($NoPrompt -or $optionalNames.Count -eq 0) {
        return @($requiredNames + $optionalNames | Select-Object -Unique)
    }

    $defaultPrompt = "Install default package set for module '$Module'?"
    $useDefaults = $true

    if (Test-WindotsGumAvailable) {
        try {
            & gum confirm $defaultPrompt
            $useDefaults = ($LASTEXITCODE -eq 0)
        }
        catch {
            $useDefaults = $true
        }
    }
    else {
        $choice = Read-Host "$defaultPrompt (Y/n)"
        if (-not [string]::IsNullOrWhiteSpace($choice) -and $choice -notin @("y", "Y", "yes", "YES")) {
            $useDefaults = $false
        }
    }

    if ($useDefaults) {
        return @($requiredNames + $optionalNames | Select-Object -Unique)
    }

    $selectedOptional = @()
    if (Test-WindotsGumAvailable) {
        try {
            $selectedOptional = @(& gum choose --no-limit --header "Select optional packages for '$Module'" @optionalNames)
        }
        catch {
            $selectedOptional = @()
        }
    }
    else {
        Log-Info "Optional packages for '$Module': $($optionalNames -join ', ')"
        $raw = Read-Host "Enter comma-separated package names (empty for none)"
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            $selectedOptional = @(
                $raw -split "," |
                    ForEach-Object { $_.Trim() } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            )
        }
    }

    $normalizedOptional = @(
        $selectedOptional |
            ForEach-Object { $_.ToString().Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )

    return @($requiredNames + $normalizedOptional | Select-Object -Unique)
}

function Test-WindotsPackageInstalled {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Package)

    if ($Package.VerifyCommand -and (Get-Command $Package.VerifyCommand -ErrorAction SilentlyContinue)) {
        return $true
    }

    if ($Package.VerifyPath) {
        $expanded = $ExecutionContext.InvokeCommand.ExpandString($Package.VerifyPath)
        if (Test-Path $expanded) {
            return $true
        }
    }

    switch ($Package.Provider) {
        'winget' { return (Test-WindotsWingetInstalled -Package $Package) }
        'mise' { return (Test-WindotsMiseInstalled -Package $Package) }
        default { throw "Unsupported provider '$($Package.Provider)'" }
    }
}

function Install-WindotsPackage {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Package)

    switch ($Package.Provider) {
        'winget' { Install-WindotsWingetPackage -Package $Package; return }
        'mise' { Install-WindotsMisePackage -Package $Package; return }
        default { throw "Unsupported provider '$($Package.Provider)'" }
    }
}

function Ensure-WindotsModulePackages {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Module,
        [ValidateSet('full', 'clean')][string]$Mode = 'full',
        [switch]$WhatIf,
        [string[]]$SelectedPackages,
        [switch]$PromptForSelection,
        [switch]$NoPrompt
    )

    $packages = Get-WindotsModulePackages -Module $Module -Mode $Mode
    if (-not $packages -or $packages.Count -eq 0) {
        Log-Info "[$Module] no packages mapped for mode '$Mode'."
        return
    }

    $normalizedSelected = @()
    $useSelectionFilter = $false
    if ($SelectedPackages -and $SelectedPackages.Count -gt 0) {
        $useSelectionFilter = $true
        $normalizedSelected = @(
            $SelectedPackages |
                ForEach-Object { $_.ToString().Trim().ToLowerInvariant() } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -Unique
        )
    }
    elseif ($PromptForSelection) {
        $useSelectionFilter = $true
        $asHashtable = @($packages | ForEach-Object { [hashtable]$_ })
        $selection = Resolve-WindotsPackageSelection -Module $Module -Packages $asHashtable -NoPrompt:$NoPrompt
        $normalizedSelected = @(
            $selection |
                ForEach-Object { $_.ToString().Trim().ToLowerInvariant() } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -Unique
        )
    }

    foreach ($pkg in $packages) {
        $pkgHt = [hashtable]$pkg

        if ($useSelectionFilter -and -not $pkgHt.Required) {
            if ($pkgHt.Name.ToLowerInvariant() -notin $normalizedSelected) {
                Log-Info "[$Module] package skipped by selection: $($pkgHt.Name)"
                continue
            }
        }

        $installed = Test-WindotsPackageInstalled -Package $pkgHt
        if ($installed) {
            Log-Info "[$Module] package already installed: $($pkgHt.Name)"
            continue
        }

        if ($WhatIf) {
            Log-Info "[$Module] WhatIf: would install package $($pkgHt.Name) via $($pkgHt.Provider)"
            continue
        }

        if (-not $pkgHt.Required) {
            try {
                Install-WindotsPackage -Package $pkgHt
            }
            catch {
                Log-Warn "[$Module] optional package failed: $($pkgHt.Name). $($_.Exception.Message)"
            }
            continue
        }

        Install-WindotsPackage -Package $pkgHt
    }
}
