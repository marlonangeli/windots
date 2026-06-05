[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Resource,

    [Parameter(Position = 1)]
    [string]$Command,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CliArgs
)

$ErrorActionPreference = "Stop"

function Write-IlegnaLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    Write-Host $Message -ForegroundColor $Color
}

function Show-IlegnaHelp {
    [CmdletBinding()]
    param()

    @"
ilegna <resource> <command> [args]

Resources:
  wt          git worktrees: list, new, remove, open, status, prune
  pr          pull requests: new, list, view, checkout
  pipeline    CI runs: list, watch, open
  jira        Jira helpers: me, mine, start, show, stop
  config      local config backups: backup, list, restore
  doctor      quick local environment check

Examples:
  ilegna wt new feat/fun-cli --base main
  ilegna wt open feat/fun-cli
  ilegna pr new --base develop --draft
  ilegna pipeline list
  ilegna jira start ABC-123 "implement CLI"
  ilegna config backup
  ilegna config restore latest --items ssh
"@
}

function Split-IlegnaArgs {
    [CmdletBinding()]
    param([string[]]$InputArgs)

    [string[]]$inputList = if ($null -eq $InputArgs) { @() } else { @($InputArgs) }
    $positionals = New-Object System.Collections.Generic.List[string]
    $options = @{}
    $flags = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

    for ($i = 0; $i -lt $inputList.Count; $i++) {
        $item = $inputList[$i]
        if ([string]::IsNullOrWhiteSpace($item)) { continue }

        $item = $item.ToString()
        if ($item.StartsWith("--")) {
            $name = $item.Substring(2)
            if ([string]::IsNullOrWhiteSpace($name)) { continue }

            $next = if ($i + 1 -lt $inputList.Count) { $inputList[$i + 1].ToString() } else { $null }
            if ($next -and -not $next.StartsWith("-")) {
                $options[$name] = $next
                $i++
            }
            else {
                $null = $flags.Add($name)
            }
            continue
        }

        $positionals.Add($item)
    }

    [pscustomobject]@{
        Positionals = @($positionals)
        Options = $options
        Flags = $flags
    }
}

function Get-IlegnaOption {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Parsed,
        [Parameter(Mandatory)][string[]]$Names,
        [string]$Default
    )

    foreach ($name in $Names) {
        if ($Parsed.Options.ContainsKey($name)) { return $Parsed.Options[$name] }
    }

    return $Default
}

function Test-IlegnaFlag {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Parsed,
        [Parameter(Mandatory)][string[]]$Names
    )

    foreach ($name in $Names) {
        if ($Parsed.Flags.Contains($name)) { return $true }
    }

    return $false
}

function Assert-GitRepository {
    [CmdletBinding()]
    param()

    git rev-parse --is-inside-work-tree *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Not inside a git repository."
    }
}

function Get-GitRoot {
    [CmdletBinding()]
    param()

    Assert-GitRepository
    $root = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($root)) {
        throw "Unable to resolve git root."
    }

    return $root.Trim()
}

function Get-DefaultBranch {
    [CmdletBinding()]
    param()

    $head = git symbolic-ref refs/remotes/origin/HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($head)) {
        return ($head.Trim() -replace '^refs/remotes/origin/', '')
    }

    git show-ref --verify --quiet refs/heads/main
    if ($LASTEXITCODE -eq 0) { return "main" }

    return "master"
}

function Get-CurrentBranch {
    [CmdletBinding()]
    param()

    $branch = git branch --show-current 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($branch)) {
        return $branch.Trim()
    }

    return $null
}

function Get-RepositoryHost {
    [CmdletBinding()]
    param()

    $remote = git remote get-url origin 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($remote)) { return "unknown" }

    if ($remote -match 'dev\.azure\.com|\.visualstudio\.com|azuredevops') { return "azure" }
    if ($remote -match 'github\.com[:/]') { return "github" }
    return "unknown"
}

function Get-WorktreePathByBranch {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Branch)

    $currentPath = $null
    $currentBranch = $null
    foreach ($line in git worktree list --porcelain) {
        if ($line -match '^worktree\s+(.+)$') {
            if ($currentPath -and $currentBranch -eq $Branch) { return $currentPath }
            $currentPath = $Matches[1]
            $currentBranch = $null
            continue
        }

        if ($line -match '^branch\s+refs/heads/(.+)$') {
            $currentBranch = $Matches[1]
        }
    }

    if ($currentPath -and $currentBranch -eq $Branch) { return $currentPath }
    return $null
}

function Get-DefaultWorktreePath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Branch)

    $root = Get-GitRoot
    $safeBranch = $Branch -replace '[^A-Za-z0-9._-]', '-'
    return (Join-Path (Join-Path $root ".worktrees") $safeBranch)
}

function Invoke-IlegnaWorktree {
    [CmdletBinding()]
    param(
        [string]$Subcommand,
        [string[]]$InputArgs
    )

    if ([string]::IsNullOrWhiteSpace($Subcommand)) { $Subcommand = "list" }
    $parsed = Split-IlegnaArgs -InputArgs $InputArgs

    switch ($Subcommand.ToLowerInvariant()) {
        "list" {
            Assert-GitRepository
            git worktree list
        }
        "new" {
            Assert-GitRepository
            $branch = $parsed.Positionals | Select-Object -First 1
            if ([string]::IsNullOrWhiteSpace($branch)) { throw "Usage: ilegna wt new <branch> [--base main] [--path .worktrees/name] [--cd]" }

            git check-ref-format --branch $branch *> $null
            if ($LASTEXITCODE -ne 0) { throw "Invalid branch name: $branch" }

            $base = Get-IlegnaOption -Parsed $parsed -Names @("base") -Default (Get-DefaultBranch)
            $path = Get-IlegnaOption -Parsed $parsed -Names @("path") -Default (Get-DefaultWorktreePath -Branch $branch)
            $cdAfter = Test-IlegnaFlag -Parsed $parsed -Names @("cd", "open")

            $parent = Split-Path -Parent $path
            if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }

            if (Test-Path $path) { throw "Worktree path already exists: $path" }

            Write-IlegnaLine "Creating worktree '$branch' from '$base'" Cyan
            git fetch origin $base *> $null
            $baseRef = if ($LASTEXITCODE -eq 0) { "origin/$base" } else { $base }

            git worktree add $path -b $branch $baseRef
            if ($LASTEXITCODE -ne 0) { throw "git worktree add failed." }

            Write-IlegnaLine "Worktree ready: $path" Green
            if ($cdAfter) { Set-Location $path }
        }
        "remove" {
            Assert-GitRepository
            $target = $parsed.Positionals | Select-Object -First 1
            if ([string]::IsNullOrWhiteSpace($target)) { throw "Usage: ilegna wt remove <branch-or-path> [--force]" }

            $path = if (Test-Path $target) { $target } else { Get-WorktreePathByBranch -Branch $target }
            if ([string]::IsNullOrWhiteSpace($path)) { throw "Worktree not found: $target" }

            $force = Test-IlegnaFlag -Parsed $parsed -Names @("force", "f")
            $status = git -C $path status --porcelain 2>$null
            if ($status -and -not $force) {
                Write-IlegnaLine "Worktree has local changes:" Yellow
                $status | ForEach-Object { Write-IlegnaLine "  $_" Yellow }
                throw "Use --force if you really want to remove it."
            }

            $removeArgs = @("worktree", "remove", $path)
            if ($force) { $removeArgs += "--force" }
            git @removeArgs
            if ($LASTEXITCODE -ne 0) { throw "git worktree remove failed." }
        }
        { $_ -in @("open", "cd") } {
            Assert-GitRepository
            $target = $parsed.Positionals | Select-Object -First 1
            if ([string]::IsNullOrWhiteSpace($target)) { throw "Usage: ilegna wt open <branch-or-path>" }

            $path = if (Test-Path $target) { $target } else { Get-WorktreePathByBranch -Branch $target }
            if ([string]::IsNullOrWhiteSpace($path)) { throw "Worktree not found: $target" }
            Set-Location $path
        }
        "status" {
            Assert-GitRepository
            $path = $null
            foreach ($line in git worktree list --porcelain) {
                if ($line -match '^worktree\s+(.+)$') {
                    $path = $Matches[1]
                    Write-IlegnaLine "`n$path" Cyan
                    git -C $path status -sb
                }
            }
        }
        "prune" {
            Assert-GitRepository
            git worktree prune
        }
        default {
            throw "Unknown wt command: $Subcommand"
        }
    }
}

function Invoke-IlegnaPullRequest {
    [CmdletBinding()]
    param(
        [string]$Subcommand,
        [string[]]$InputArgs
    )

    if ([string]::IsNullOrWhiteSpace($Subcommand)) { $Subcommand = "list" }
    $parsed = Split-IlegnaArgs -InputArgs $InputArgs

    switch ($Subcommand.ToLowerInvariant()) {
        "new" {
            Assert-GitRepository
            $base = Get-IlegnaOption -Parsed $parsed -Names @("base", "target") -Default (Get-DefaultBranch)
            $title = Get-IlegnaOption -Parsed $parsed -Names @("title")
            $body = Get-IlegnaOption -Parsed $parsed -Names @("body")
            $draft = Test-IlegnaFlag -Parsed $parsed -Names @("draft")
            $currentBranch = Get-CurrentBranch

            if (Get-Command gh -ErrorAction SilentlyContinue) {
                $ghArgs = @("pr", "create", "--base", $base)
                if ($draft) { $ghArgs += "--draft" }
                if ($title) { $ghArgs += @("--title", $title) } else { $ghArgs += "--fill" }
                if ($body) { $ghArgs += @("--body", $body) }
                gh @ghArgs
                return
            }

            if (Get-Command az -ErrorAction SilentlyContinue) {
                if ([string]::IsNullOrWhiteSpace($title)) { $title = $currentBranch }
                $azArgs = @("repos", "pr", "create", "--source-branch", $currentBranch, "--target-branch", $base, "--title", $title)
                if ($draft) { $azArgs += @("--draft", "true") }
                if ($body) { $azArgs += @("--description", $body) }
                az @azArgs
                return
            }

            throw "Install gh or az to create pull requests."
        }
        "list" {
            if (Get-Command gh -ErrorAction SilentlyContinue) { gh pr list @InputArgs; return }
            if (Get-Command az -ErrorAction SilentlyContinue) { az repos pr list @InputArgs; return }
            throw "Install gh or az to list pull requests."
        }
        "view" {
            if (Get-Command gh -ErrorAction SilentlyContinue) { gh pr view --web @InputArgs; return }
            throw "Install gh to view pull requests from this command."
        }
        "checkout" {
            if (Get-Command gh -ErrorAction SilentlyContinue) { gh pr checkout @InputArgs; return }
            throw "Install gh to checkout pull requests."
        }
        default {
            throw "Unknown pr command: $Subcommand"
        }
    }
}

function Invoke-IlegnaPipeline {
    [CmdletBinding()]
    param(
        [string]$Subcommand,
        [string[]]$InputArgs
    )

    if ([string]::IsNullOrWhiteSpace($Subcommand)) { $Subcommand = "list" }
    $hostName = Get-RepositoryHost
    $parsed = Split-IlegnaArgs -InputArgs $InputArgs

    function Get-PipelineRunId {
        $id = Get-IlegnaOption -Parsed $parsed -Names @("id", "run")
        if (-not [string]::IsNullOrWhiteSpace($id)) { return $id }
        return ($parsed.Positionals | Select-Object -First 1)
    }

    switch ($Subcommand.ToLowerInvariant()) {
        "list" {
            if ($hostName -eq "azure") {
                if (Get-Command az -ErrorAction SilentlyContinue) { az pipelines runs list @InputArgs; return }
                throw "This looks like an Azure repo, but az was not found."
            }
            if ($hostName -eq "github") {
                if (Get-Command gh -ErrorAction SilentlyContinue) { gh run list @InputArgs; return }
                throw "This looks like a GitHub repo, but gh was not found."
            }
            if (Get-Command gh -ErrorAction SilentlyContinue) { gh run list @InputArgs; return }
            if (Get-Command az -ErrorAction SilentlyContinue) { az pipelines runs list @InputArgs; return }
            throw "Install gh or az to list pipeline runs."
        }
        "watch" {
            if ($hostName -eq "azure") {
                if (-not (Get-Command az -ErrorAction SilentlyContinue)) { throw "This looks like an Azure repo, but az was not found." }
                $runId = Get-PipelineRunId
                if ([string]::IsNullOrWhiteSpace($runId)) { throw "Usage: ilegna pipeline watch <run-id>" }

                while ($true) {
                    $run = az pipelines runs show --id $runId --query "{id:id,status:status,result:result,branch:sourceBranch}" -o json | ConvertFrom-Json
                    Write-IlegnaLine ("{0} status={1} result={2} branch={3}" -f $run.id, $run.status, $run.result, $run.branch) Cyan
                    if ($run.status -eq "completed") { return }
                    Start-Sleep -Seconds 10
                }
            }

            if (Get-Command gh -ErrorAction SilentlyContinue) { gh run watch @InputArgs; return }
            throw "Install gh to watch GitHub Actions runs."
        }
        { $_ -in @("open", "view") } {
            if ($hostName -eq "azure") {
                if (-not (Get-Command az -ErrorAction SilentlyContinue)) { throw "This looks like an Azure repo, but az was not found." }
                $runId = Get-PipelineRunId
                if ([string]::IsNullOrWhiteSpace($runId)) { throw "Usage: ilegna pipeline open <run-id>" }
                az pipelines runs show --id $runId --open
                return
            }

            if (Get-Command gh -ErrorAction SilentlyContinue) { gh run view --web @InputArgs; return }
            throw "Install gh to open GitHub Actions runs."
        }
        default {
            throw "Unknown pipeline command: $Subcommand"
        }
    }
}

function Get-IlegnaStateRoot {
    [CmdletBinding()]
    param()

    $base = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $HOME ".local\share" }
    $root = Join-Path $base "ilegna"
    if (-not (Test-Path $root)) { New-Item -ItemType Directory -Path $root -Force | Out-Null }
    return $root
}

function Get-IlegnaTimerPath {
    [CmdletBinding()]
    param()

    Join-Path (Get-IlegnaStateRoot) "work-timer.json"
}

function Get-IlegnaTimer {
    [CmdletBinding()]
    param()

    $path = Get-IlegnaTimerPath
    if (-not (Test-Path $path)) { return $null }
    Get-Content -Path $path -Raw | ConvertFrom-Json
}

function Invoke-IlegnaJira {
    [CmdletBinding()]
    param(
        [string]$Subcommand,
        [string[]]$InputArgs
    )

    if ([string]::IsNullOrWhiteSpace($Subcommand)) { $Subcommand = "mine" }
    $parsed = Split-IlegnaArgs -InputArgs $InputArgs

    switch ($Subcommand.ToLowerInvariant()) {
        "me" {
            if (-not (Get-Command jira -ErrorAction SilentlyContinue)) { throw "jira CLI not found." }
            jira me
        }
        "mine" {
            if (-not (Get-Command jira -ErrorAction SilentlyContinue)) { throw "jira CLI not found." }
            jira issue list --assignee "@me" @InputArgs
        }
        "start" {
            $issue = $parsed.Positionals | Select-Object -First 1
            if ([string]::IsNullOrWhiteSpace($issue)) { throw "Usage: ilegna jira start <ISSUE-123> [description]" }

            $description = @($parsed.Positionals | Select-Object -Skip 1) -join " "
            $timer = [pscustomobject]@{
                issue = $issue
                description = $description
                startedAt = (Get-Date).ToString("o")
            }
            $timer | ConvertTo-Json | Set-Content -Path (Get-IlegnaTimerPath) -Encoding UTF8
            Write-IlegnaLine "Timer started for $issue" Green
        }
        "show" {
            $timer = Get-IlegnaTimer
            if (-not $timer) { Write-IlegnaLine "No active timer." Yellow; return }

            $started = [datetime]::Parse($timer.startedAt)
            $elapsed = New-TimeSpan -Start $started -End (Get-Date)
            Write-IlegnaLine ("{0} running for {1:hh\:mm}" -f $timer.issue, $elapsed) Cyan
            if ($timer.description) { Write-IlegnaLine $timer.description DarkGray }
        }
        "stop" {
            $timer = Get-IlegnaTimer
            if (-not $timer) { Write-IlegnaLine "No active timer." Yellow; return }

            $started = [datetime]::Parse($timer.startedAt)
            $elapsed = New-TimeSpan -Start $started -End (Get-Date)
            $minutes = [Math]::Max(1, [Math]::Ceiling($elapsed.TotalMinutes))
            $log = Test-IlegnaFlag -Parsed $parsed -Names @("log")

            if ($log) {
                if (-not (Get-Command jira -ErrorAction SilentlyContinue)) { throw "jira CLI not found." }
                $comment = if ($timer.description) { $timer.description } else { "Work logged from ilegna" }
                jira issue worklog add $timer.issue --time-spent "$($minutes)m" --comment $comment
            }

            Remove-Item -Path (Get-IlegnaTimerPath) -Force
            Write-IlegnaLine ("Timer stopped for {0}: {1}m" -f $timer.issue, $minutes) Green
        }
        default {
            throw "Unknown jira command: $Subcommand"
        }
    }
}

function Invoke-IlegnaDoctor {
    [CmdletBinding()]
    param()

    $checks = @(
        @{ Name = "git"; Command = "git" },
        @{ Name = "chezmoi"; Command = "chezmoi" },
        @{ Name = "mise"; Command = "mise" },
        @{ Name = "starship"; Command = "starship" },
        @{ Name = "zoxide"; Command = "zoxide" },
        @{ Name = "gh"; Command = "gh" },
        @{ Name = "az"; Command = "az" },
        @{ Name = "jira"; Command = "jira" },
        @{ Name = "codex"; Command = "codex" },
        @{ Name = "opencode"; Command = "opencode" }
    )

    foreach ($check in $checks) {
        if (Get-Command $check.Command -ErrorAction SilentlyContinue) {
            Write-IlegnaLine ("ok   {0}" -f $check.Name) Green
        }
        else {
            Write-IlegnaLine ("miss {0}" -f $check.Name) Yellow
        }
    }
}

function Invoke-IlegnaConfig {
    [CmdletBinding()]
    param(
        [string]$Subcommand,
        [string[]]$InputArgs
    )

    if ([string]::IsNullOrWhiteSpace($Subcommand)) { $Subcommand = "backup" }

    $scriptPath = Join-Path $PSScriptRoot "config-backup.ps1"
    if (-not (Test-Path $scriptPath)) {
        throw "Config backup script not found: $scriptPath"
    }

    $parsed = Split-IlegnaArgs -InputArgs $InputArgs
    $items = Get-IlegnaOption -Parsed $parsed -Names @("items", "item") -Default "all"
    $version = Get-IlegnaOption -Parsed $parsed -Names @("version")
    $force = Test-IlegnaFlag -Parsed $parsed -Names @("force", "f")

    switch ($Subcommand.ToLowerInvariant()) {
        { $_ -in @("backup", "create") } {
            & $scriptPath -Action backup -Items ($items -split ",")
        }
        "list" {
            & $scriptPath -Action list
        }
        "restore" {
            $positionalVersion = $parsed.Positionals | Select-Object -First 1
            if ([string]::IsNullOrWhiteSpace($version)) { $version = $positionalVersion }
            & $scriptPath -Action restore -Version $version -Items ($items -split ",") -Force:$force
        }
        default {
            throw "Unknown config command: $Subcommand"
        }
    }
}

try {
    if ([string]::IsNullOrWhiteSpace($Resource) -or $Resource -in @("help", "-h", "--help")) {
        Show-IlegnaHelp
        return
    }

    switch ($Resource.ToLowerInvariant()) {
        { $_ -in @("wt", "worktree", "worktrees") } { Invoke-IlegnaWorktree -Subcommand $Command -InputArgs $CliArgs; break }
        { $_ -in @("pr", "pull-request", "pull-requests") } { Invoke-IlegnaPullRequest -Subcommand $Command -InputArgs $CliArgs; break }
        { $_ -in @("pipeline", "pipelines", "ci") } { Invoke-IlegnaPipeline -Subcommand $Command -InputArgs $CliArgs; break }
        "jira" { Invoke-IlegnaJira -Subcommand $Command -InputArgs $CliArgs; break }
        "config" { Invoke-IlegnaConfig -Subcommand $Command -InputArgs $CliArgs; break }
        "doctor" { Invoke-IlegnaDoctor; break }
        default { throw "Unknown resource: $Resource" }
    }
}
catch {
    throw $_.Exception.Message
}
