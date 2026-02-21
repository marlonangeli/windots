[CmdletBinding()]
param()

function Test-WindotsGumAvailable {
    [CmdletBinding()]
    param()

    return $null -ne (Get-Command gum -ErrorAction SilentlyContinue)
}

function Invoke-WindotsPromptInput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Label,
        [string]$Default = "",
        [switch]$NoPrompt
    )

    if ($NoPrompt) { return $Default }

    if (Test-WindotsGumAvailable) {
        $placeholder = if ([string]::IsNullOrWhiteSpace($Default)) { $Label } else { "$Label [$Default]" }
        try {
            $value = & gum input --placeholder $placeholder
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($value)) {
                return $value
            }
        }
        catch {
            # fallback handled below
        }
    }

    $suffix = if ([string]::IsNullOrWhiteSpace($Default)) { "" } else { " [$Default]" }
    $value = Read-Host "$Label$suffix"
    if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
    return $value
}

function Invoke-WindotsPromptConfirm {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [switch]$DefaultYes,
        [switch]$NoPrompt
    )

    if ($NoPrompt) { return [bool]$DefaultYes }

    if (Test-WindotsGumAvailable) {
        try {
            & gum confirm $Message
            return ($LASTEXITCODE -eq 0)
        }
        catch {
            # fallback handled below
        }
    }

    $hint = if ($DefaultYes) { "(Y/n)" } else { "(y/N)" }
    $value = Read-Host "$Message $hint"
    if ([string]::IsNullOrWhiteSpace($value)) { return [bool]$DefaultYes }
    return $value -in @("y", "Y", "yes", "YES")
}

function Invoke-WindotsPromptMultiSelect {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][string[]]$Options,
        [string[]]$Default = @(),
        [switch]$NoPrompt
    )

    if ($NoPrompt) {
        if ($Default -and $Default.Count -gt 0) { return $Default }
        return $Options
    }

    if (Test-WindotsGumAvailable) {
        try {
            $selected = & gum choose --no-limit --header $Message @Options
            if ($LASTEXITCODE -eq 0 -and $selected) {
                if ($selected -is [string]) { return @($selected) }
                return @($selected | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            }
        }
        catch {
            # fallback handled below
        }
    }

    Write-Host $Message -ForegroundColor Cyan
    Write-Host ("Options: " + ($Options -join ", ")) -ForegroundColor DarkGray
    if ($Default -and $Default.Count -gt 0) {
        Write-Host ("Default: " + ($Default -join ", ")) -ForegroundColor DarkGray
    }

    $raw = Read-Host "Enter comma-separated module names (leave empty for default)"
    if ([string]::IsNullOrWhiteSpace($raw)) {
        if ($Default -and $Default.Count -gt 0) { return $Default }
        return $Options
    }

    return @(
        $raw -split "," |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}
