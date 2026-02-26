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
    $useDefaults = Confirm-WindotsChoice -Message $defaultPrompt -DefaultYes -NoPrompt:$NoPrompt

    if ($useDefaults) {
        return @($requiredNames + $optionalNames | Select-Object -Unique)
    }

    $selectedOptional = @()
    Log-Info "Optional packages for '$Module': $($optionalNames -join ', ')"
    $raw = Read-WindotsInput -Prompt "Enter comma-separated package names (empty for none)"
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        $selectedOptional = @(
            $raw -split "," |
                ForEach-Object { $_.Trim() } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
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
        'winget' {
            return (Test-WindotsWingetInstalled -Package $Package)
        }
        'mise' {
            return (Test-WindotsMiseInstalled -Package $Package)
        }
        default {
            throw "Unsupported provider '$($Package.Provider)'"
        }
    }
}

function Install-WindotsPackage {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Package)

    switch ($Package.Provider) {
        'winget' {
            Install-WindotsWingetPackage -Package $Package; return
        }
        'mise' {
            Install-WindotsMisePackage -Package $Package; return
        }
        default {
            throw "Unsupported provider '$($Package.Provider)'"
        }
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
        $packageLabel = if ($pkgHt.Name) {
            $pkgHt.Name
        }
        else {
            $pkgHt.PackageId
        }

        if ($useSelectionFilter -and -not $pkgHt.Required) {
            if ($pkgHt.Name.ToLowerInvariant() -notin $normalizedSelected) {
                Log-PackageStatus -Package $packageLabel -Status "skipped by selection" -StatusColor Yellow -FileLevel "WARN"
                continue
            }
        }

        if ($pkgHt.Provider -eq 'mise' -and -not (Get-Command mise -ErrorAction SilentlyContinue)) {
            if ($pkgHt.Required) {
                throw "required package '$packageLabel' needs mise, but mise is not available in PATH"
            }

            Log-PackageStatus -Package $packageLabel -Status "skipped: provider 'mise' is not available yet" -StatusColor Yellow -FileLevel "WARN"
            continue
        }

        $installed = Test-WindotsPackageInstalled -Package $pkgHt
        if ($installed) {
            Log-PackageStatus -Package $packageLabel -Status "is installed" -StatusColor Green
            continue
        }

        Log-PackageStatus -Package $packageLabel -Status "is not installed" -StatusColor Cyan

        if ($WhatIf) {
            Log-Output ("WhatIf: would install via provider '{0}'." -f $pkgHt.Provider)
            continue
        }

        Log-Step ("installing package {0}" -f $packageLabel)

        if (-not $pkgHt.Required) {
            try {
                Install-WindotsPackage -Package $pkgHt
                Log-PackageStatus -Package $packageLabel -Status "installed successfully" -StatusColor Green
            }
            catch {
                Log-Warn ("failed to install (optional): {0}" -f $_.Exception.Message)
            }
            continue
        }

        try {
            Install-WindotsPackage -Package $pkgHt
            Log-PackageStatus -Package $packageLabel -Status "installed successfully" -StatusColor Green
        }
        catch {
            Log-Error ("failed to install: {0}" -f $_.Exception.Message)
            throw
        }
    }
}
