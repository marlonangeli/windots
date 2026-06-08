function groot {
    [CmdletBinding()]
    param()

    $root = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and $root) { Set-Location $root }
}

function gdefault {
    [CmdletBinding()]
    param()

    $branch = git symbolic-ref refs/remotes/origin/HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $branch) { return ($branch -replace '^refs/remotes/origin/', '') }
    if (git show-ref --verify --quiet refs/heads/main) { return "main" }
    return "master"
}

function gsync {
    [CmdletBinding()]
    param([string]$Branch = (gdefault))

    git fetch origin $Branch
    if ($LASTEXITCODE -ne 0) { return }
    git switch $Branch
    if ($LASTEXITCODE -ne 0) { return }
    git pull --ff-only origin $Branch
}

$global:__WindotsWorktrunkLoaded = $false
function Enable-Worktrunk {
    [CmdletBinding()]
    param()

    if ($global:__WindotsWorktrunkLoaded) { return $true }
    if (-not (Get-Command git-wt -ErrorAction SilentlyContinue)) { return $false }

    if (Invoke-ShellInitScript -Command "git-wt" -Arguments @("config", "shell", "init", "powershell")) {
        $global:__WindotsWorktrunkLoaded = $true
        return $true
    }

    return $false
}

if ($env:WINDOTS_WORKTRUNK -eq "1") {
    Enable-Worktrunk | Out-Null
}
