[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Resource,

    [Parameter(Position = 1)]
    [string]$Command,

    [Alias("i")]
    [switch]$Interactive,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CliArgs
)

$ErrorActionPreference = "Stop"
$LegacyIlegnaPath = Join-Path $PSScriptRoot "ilegna.ps1"

function Write-IlegnaLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    Write-Host $Message -ForegroundColor $Color
}

function Test-HelpRequest {
    [CmdletBinding()]
    param([AllowNull()][string[]]$Values)

    foreach ($value in @($Values)) {
        if ($value -in @("help", "-h", "--help")) {
            return $true
        }
    }

    return $false
}

function ConvertTo-ResourceName {
    [CmdletBinding()]
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    switch ($Value.ToLowerInvariant()) {
        { $_ -in @("cm", "chezmoi") } { return "chezmoi" }
        "task" { return "task" }
        { $_ -in @("git", "g") } { return "git" }
        default { return $Value.ToLowerInvariant() }
    }
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

        if ($item -eq "--") {
            for ($j = $i + 1; $j -lt $inputList.Count; $j++) {
                $positionals.Add($inputList[$j])
            }
            break
        }

        if ($item.StartsWith("--")) {
            $name = $item.Substring(2)
            $separatorIndex = $name.IndexOf("=")
            if ($separatorIndex -ge 0) {
                $options[$name.Substring(0, $separatorIndex)] = $name.Substring($separatorIndex + 1)
                continue
            }

            $next = if ($i + 1 -lt $inputList.Count) { $inputList[$i + 1] } else { $null }
            if ($next -and -not $next.StartsWith("-")) {
                $options[$name] = $next
                $i++
            }
            else {
                $null = $flags.Add($name)
            }
            continue
        }

        if ($item.StartsWith("-") -and $item.Length -gt 1) {
            $name = $item.Substring(1)
            $next = if ($i + 1 -lt $inputList.Count) { $inputList[$i + 1] } else { $null }
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
        if ($Parsed.Options.ContainsKey($name)) {
            return $Parsed.Options[$name]
        }
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
        if ($Parsed.Flags.Contains($name)) {
            return $true
        }
    }

    return $false
}

function Assert-Command {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function Invoke-ExternalCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string[]]$Arguments = @()
    )

    Assert-Command -Name $Name
    & $Name @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE."
    }
}

function Invoke-LegacyIlegna {
    [CmdletBinding()]
    param([string[]]$Arguments)

    if (-not (Test-Path -LiteralPath $LegacyIlegnaPath)) {
        throw "Legacy ilegna script not found: $LegacyIlegnaPath"
    }

    & $LegacyIlegnaPath @Arguments
}

function Assert-GitRepository {
    [CmdletBinding()]
    param()

    git rev-parse --is-inside-work-tree *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Not inside a git repository."
    }
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

function Get-DefaultBranch {
    [CmdletBinding()]
    param()

    $head = git symbolic-ref refs/remotes/origin/HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($head)) {
        return ($head.Trim() -replace '^refs/remotes/origin/', '')
    }

    git show-ref --verify --quiet refs/heads/main
    if ($LASTEXITCODE -eq 0) {
        return "main"
    }

    return "master"
}

function Expand-IlegnaPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if ($expanded -eq "~") { return $HOME }
    if ($expanded.StartsWith("~/") -or $expanded.StartsWith("~\")) {
        return (Join-Path $HOME $expanded.Substring(2))
    }

    return $expanded
}

function Get-StateRoot {
    [CmdletBinding()]
    param()

    $base = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $HOME ".local\share" }
    $root = Join-Path $base "ilegna"
    if (-not (Test-Path -LiteralPath $root)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }

    return $root
}

function Get-TaskRoot {
    [CmdletBinding()]
    param()

    $root = Join-Path (Get-StateRoot) "tasks"
    if (-not (Test-Path -LiteralPath $root)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }

    return $root
}

function ConvertTo-Slug {
    [CmdletBinding()]
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return "work" }
    $slug = $Value.Trim().ToLowerInvariant() -replace '[^a-z0-9]+', '-'
    $slug = $slug.Trim('-')
    if ([string]::IsNullOrWhiteSpace($slug)) { return "work" }
    if ($slug.Length -gt 48) { return $slug.Substring(0, 48).Trim('-') }
    return $slug
}

function Get-IssueFromText {
    [CmdletBinding()]
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    if ($Value -match '([A-Z][A-Z0-9]+-\d+)') { return $Matches[1] }
    return $null
}

function New-TaskBranchName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Issue,
        [string]$Summary,
        [string]$Type = "feat"
    )

    "{0}/{1}-{2}" -f (ConvertTo-Slug -Value $Type), $Issue.ToUpperInvariant(), (ConvertTo-Slug -Value $Summary)
}

function Get-TaskStatePath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Issue)

    $fileName = ($Issue.ToUpperInvariant() -replace '[^A-Z0-9-]', '-') + ".json"
    Join-Path (Get-TaskRoot) $fileName
}

function Save-TaskState {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$State)

    $path = Get-TaskStatePath -Issue $State.issue
    $State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding UTF8
    $path
}

function Get-TaskState {
    [CmdletBinding()]
    param([string]$Issue)

    if ([string]::IsNullOrWhiteSpace($Issue)) {
        $Issue = Get-IssueFromText -Value (Get-CurrentBranch)
    }
    if ([string]::IsNullOrWhiteSpace($Issue)) { return $null }

    $path = Get-TaskStatePath -Issue $Issue
    if (-not (Test-Path -LiteralPath $path)) { return $null }

    Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -ErrorAction Stop
}

function Show-Help {
    [CmdletBinding()]
    param([string]$HelpResource)

    switch (ConvertTo-ResourceName -Value $HelpResource) {
        "chezmoi" {
@"
ilegna cm <command> [args]

Commands:
  capture <path...> [--apply] [--edit] [--dry-run]
  refresh [path...]
  diff | status | unmanaged | managed | source | edit <path> | apply
"@
            return
        }
        "task" {
@"
ilegna task <command> [args]

Commands:
  start <ISSUE> [summary] [--type feat] [--base develop] [--path path] [--cd]
  link <ISSUE> [summary] [--base develop]
  show [ISSUE]
  pr [--ready]
  pipeline [raw pipeline args]
  done [--log|--no-log]
"@
            return
        }
        "git" {
@"
ilegna git <command> [args]

Commands:
  status
  sync [--pull] [--tags]
  publish [--pr] [--ready]
  clean-merged [--base develop] [--dry-run]
"@
            return
        }
    }

@"
ilegna <resource> <command> [args]

Workflow overlay resources:
  cm       chezmoi capture/re-add/review helpers
  task     Jira/worktree/branch/PR/pipeline glue
  git      daily Git status/sync/publish helpers

Legacy resources are delegated to scripts/ilegna.ps1:
  wt, git-bare, pr, pipeline, jira, config, doctor

Examples:
  ilegna task start AL-1541 implement csv import --type feat --base develop --cd
  ilegna cm capture `$PROFILE --edit
  ilegna git publish --pr
"@
}

function Invoke-ChezmoiResource {
    [CmdletBinding()]
    param([string]$Subcommand, [string[]]$InputArgs)

    if ([string]::IsNullOrWhiteSpace($Subcommand)) { $Subcommand = "status" }
    $parsed = Split-IlegnaArgs -InputArgs $InputArgs

    switch ($Subcommand.ToLowerInvariant()) {
        { $_ -in @("status", "st") } { Invoke-ExternalCommand -Name "chezmoi" -Arguments (@("status") + @($InputArgs)) }
        "diff" { Invoke-ExternalCommand -Name "chezmoi" -Arguments (@("diff") + @($InputArgs)) }
        "source" { Invoke-ExternalCommand -Name "chezmoi" -Arguments @("source-path") }
        "managed" { Invoke-ExternalCommand -Name "chezmoi" -Arguments (@("managed") + @($InputArgs)) }
        "unmanaged" { Invoke-ExternalCommand -Name "chezmoi" -Arguments (@("unmanaged") + @($InputArgs)) }
        { $_ -in @("capture", "add") } {
            $targets = @($parsed.Positionals)
            if ($targets.Count -eq 0) { throw "Usage: ilegna cm capture <path...> [--apply] [--edit] [--dry-run]" }

            $dryRun = Test-IlegnaFlag -Parsed $parsed -Names @("dry-run", "whatif", "no-op")
            $edit = Test-IlegnaFlag -Parsed $parsed -Names @("edit")
            $apply = Test-IlegnaFlag -Parsed $parsed -Names @("apply")

            foreach ($target in $targets) {
                $expandedTarget = Expand-IlegnaPath -Path $target
                if ($dryRun) {
                    Write-IlegnaLine ("chezmoi add {0}" -f $expandedTarget) DarkGray
                }
                else {
                    Invoke-ExternalCommand -Name "chezmoi" -Arguments @("add", $expandedTarget)
                }

                if ($edit) {
                    if ($dryRun) {
                        Write-IlegnaLine ("chezmoi edit {0}" -f $expandedTarget) DarkGray
                    }
                    else {
                        Invoke-ExternalCommand -Name "chezmoi" -Arguments @("edit", $expandedTarget)
                    }
                }
            }

            if ($dryRun) {
                Write-IlegnaLine "Dry-run complete. No chezmoi state changed." Yellow
                return
            }

            Invoke-ExternalCommand -Name "chezmoi" -Arguments @("diff")
            if ($apply) { Invoke-ExternalCommand -Name "chezmoi" -Arguments @("apply") }
        }
        { $_ -in @("refresh", "re-add", "readd") } {
            $arguments = @("re-add")
            foreach ($target in @($parsed.Positionals)) { $arguments += (Expand-IlegnaPath -Path $target) }
            Invoke-ExternalCommand -Name "chezmoi" -Arguments $arguments
            Invoke-ExternalCommand -Name "chezmoi" -Arguments @("diff")
        }
        "edit" {
            $target = $parsed.Positionals | Select-Object -First 1
            if ([string]::IsNullOrWhiteSpace($target)) { throw "Usage: ilegna cm edit <path>" }
            Invoke-ExternalCommand -Name "chezmoi" -Arguments @("edit", (Expand-IlegnaPath -Path $target))
        }
        "apply" { Invoke-ExternalCommand -Name "chezmoi" -Arguments (@("apply") + @($InputArgs)) }
        default { throw "Unknown chezmoi command: $Subcommand" }
    }
}

function Invoke-TaskResource {
    [CmdletBinding()]
    param([string]$Subcommand, [string[]]$InputArgs)

    if ([string]::IsNullOrWhiteSpace($Subcommand)) { $Subcommand = "show" }
    $parsed = Split-IlegnaArgs -InputArgs $InputArgs

    switch ($Subcommand.ToLowerInvariant()) {
        { $_ -in @("start", "new") } {
            Assert-GitRepository
            $issue = $parsed.Positionals | Select-Object -First 1
            if ([string]::IsNullOrWhiteSpace($issue)) { throw "Usage: ilegna task start <ISSUE-123> [summary] [--type feat] [--base develop]" }

            $summary = @($parsed.Positionals | Select-Object -Skip 1) -join " "
            $base = Get-IlegnaOption -Parsed $parsed -Names @("base", "target") -Default (Get-DefaultBranch)
            $type = Get-IlegnaOption -Parsed $parsed -Names @("type", "kind") -Default "feat"
            $branch = Get-IlegnaOption -Parsed $parsed -Names @("branch", "b")
            if ([string]::IsNullOrWhiteSpace($branch)) { $branch = New-TaskBranchName -Issue $issue -Summary $summary -Type $type }

            if (Test-IlegnaFlag -Parsed $parsed -Names @("no-worktree")) {
                git fetch origin $base *> $null
                $baseRef = if ($LASTEXITCODE -eq 0) { "FETCH_HEAD" } else { $base }
                git checkout -b $branch $baseRef
                if ($LASTEXITCODE -ne 0) { throw "git checkout failed for '$branch'." }
                $worktreePath = (Get-Location).ProviderPath
            }
            else {
                [string[]]$wtArgs = @("wt", "new", $branch, "--base", $base)
                $path = Get-IlegnaOption -Parsed $parsed -Names @("path", "location", "name")
                if (-not [string]::IsNullOrWhiteSpace($path)) { $wtArgs += @("--path", $path) }
                if (Test-IlegnaFlag -Parsed $parsed -Names @("cd", "open")) { $wtArgs += "--cd" }
                Invoke-LegacyIlegna -Arguments $wtArgs
                $worktreePath = if ([string]::IsNullOrWhiteSpace($path)) { $null } else { Expand-IlegnaPath -Path $path }
            }

            if (-not (Test-IlegnaFlag -Parsed $parsed -Names @("no-timer", "skip-timer"))) {
                Invoke-LegacyIlegna -Arguments (@("jira", "start", $issue) + @($summary))
            }

            $state = [pscustomobject]@{
                issue = $issue.ToUpperInvariant()
                summary = $summary
                branch = $branch
                base = $base
                worktreePath = $worktreePath
                createdAt = (Get-Date).ToString("o")
            }
            $statePath = Save-TaskState -State $state
            Write-IlegnaLine ("Task linked: {0}" -f $statePath) Green
        }
        "link" {
            Assert-GitRepository
            $issue = $parsed.Positionals | Select-Object -First 1
            if ([string]::IsNullOrWhiteSpace($issue)) { throw "Usage: ilegna task link <ISSUE-123> [summary]" }
            $state = [pscustomobject]@{
                issue = $issue.ToUpperInvariant()
                summary = @($parsed.Positionals | Select-Object -Skip 1) -join " "
                branch = Get-CurrentBranch
                base = Get-IlegnaOption -Parsed $parsed -Names @("base", "target") -Default (Get-DefaultBranch)
                worktreePath = (Get-Location).ProviderPath
                createdAt = (Get-Date).ToString("o")
            }
            Write-IlegnaLine ("Task linked: {0}" -f (Save-TaskState -State $state)) Green
        }
        { $_ -in @("show", "status") } {
            $state = Get-TaskState -Issue ($parsed.Positionals | Select-Object -First 1)
            if (-not $state) { Write-IlegnaLine "No task state found for current branch." Yellow; return }
            Write-IlegnaLine ("issue={0}" -f $state.issue) Cyan
            Write-IlegnaLine ("branch={0}" -f $state.branch) Cyan
            if ($state.base) { Write-IlegnaLine ("base={0}" -f $state.base) Cyan }
            if ($state.worktreePath) { Write-IlegnaLine ("worktree={0}" -f $state.worktreePath) Cyan }
            if ($state.summary) { Write-IlegnaLine ("summary={0}" -f $state.summary) Cyan }
        }
        "pr" {
            Assert-GitRepository
            $state = Get-TaskState -Issue ($parsed.Positionals | Select-Object -First 1)
            $base = Get-IlegnaOption -Parsed $parsed -Names @("base", "target") -Default $(if ($state -and $state.base) { $state.base } else { "develop" })
            $title = Get-IlegnaOption -Parsed $parsed -Names @("title")
            if ([string]::IsNullOrWhiteSpace($title) -and $state) {
                $title = if ([string]::IsNullOrWhiteSpace($state.summary)) { $state.branch } else { "[{0}] {1}" -f $state.issue, $state.summary }
            }
            [string[]]$prArgs = @("pr", "new", "--base", $base)
            if (-not [string]::IsNullOrWhiteSpace($title)) { $prArgs += @("--title", $title) }
            if (Test-IlegnaFlag -Parsed $parsed -Names @("ready")) { $prArgs += "--ready" }
            Invoke-LegacyIlegna -Arguments $prArgs
        }
        "pipeline" {
            $pipelineCommand = $parsed.Positionals | Select-Object -First 1
            if ([string]::IsNullOrWhiteSpace($pipelineCommand)) { $pipelineCommand = "list" }
            [string[]]$pipelineArgs = @("pipeline", $pipelineCommand) + @($InputArgs | Select-Object -Skip 1)
            if ($pipelineCommand -in @("trigger", "run", "start") -and -not (Test-IlegnaFlag -Parsed (Split-IlegnaArgs -InputArgs $pipelineArgs) -Names @("branch", "b"))) {
                $branch = Get-CurrentBranch
                if (-not [string]::IsNullOrWhiteSpace($branch)) { $pipelineArgs += @("--branch", $branch) }
            }
            Invoke-LegacyIlegna -Arguments $pipelineArgs
        }
        { $_ -in @("done", "finish", "stop") } {
            $state = Get-TaskState
            [string[]]$stopArgs = @("jira", "stop")
            if ($state -and $state.issue) { $stopArgs += $state.issue }
            $stopArgs += @($InputArgs)
            Invoke-LegacyIlegna -Arguments $stopArgs
        }
        default { throw "Unknown task command: $Subcommand" }
    }
}

function Invoke-GitResource {
    [CmdletBinding()]
    param([string]$Subcommand, [string[]]$InputArgs)

    if ([string]::IsNullOrWhiteSpace($Subcommand)) { $Subcommand = "status" }
    $parsed = Split-IlegnaArgs -InputArgs $InputArgs

    switch ($Subcommand.ToLowerInvariant()) {
        "status" {
            Assert-GitRepository
            $branch = Get-CurrentBranch
            $upstream = git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null
            Write-IlegnaLine ("branch={0}" -f $(if ($branch) { $branch } else { "<detached>" })) Cyan
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($upstream)) { Write-IlegnaLine ("upstream={0}" -f $upstream.Trim()) Cyan }
            git status -sb
        }
        "sync" {
            Assert-GitRepository
            $remote = Get-IlegnaOption -Parsed $parsed -Names @("remote", "r") -Default "origin"
            $fetchArgs = @("fetch", "--prune", $remote)
            if (Test-IlegnaFlag -Parsed $parsed -Names @("tags")) { $fetchArgs += "--tags" }
            Invoke-ExternalCommand -Name "git" -Arguments $fetchArgs
            if (Test-IlegnaFlag -Parsed $parsed -Names @("pull", "ff")) { Invoke-ExternalCommand -Name "git" -Arguments @("pull", "--ff-only", $remote, (Get-CurrentBranch)) }
        }
        "publish" {
            Assert-GitRepository
            $branch = Get-CurrentBranch
            if ([string]::IsNullOrWhiteSpace($branch)) { throw "Cannot publish from detached HEAD." }
            Invoke-ExternalCommand -Name "git" -Arguments @("push", "-u", "origin", $branch)
            if (Test-IlegnaFlag -Parsed $parsed -Names @("pr")) {
                Invoke-TaskResource -Subcommand "pr" -InputArgs @($InputArgs | Where-Object { $_ -ne "--pr" })
            }
        }
        "clean-merged" {
            Assert-GitRepository
            $base = Get-IlegnaOption -Parsed $parsed -Names @("base", "target") -Default (Get-DefaultBranch)
            $dryRun = Test-IlegnaFlag -Parsed $parsed -Names @("dry-run", "whatif", "no-op")
            $protected = @($base, "main", "master", "develop", "development")
            $current = Get-CurrentBranch
            $branches = git branch --merged $base | ForEach-Object { $_.ToString().Trim().TrimStart("* ").Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -notin $protected -and $_ -ne $current }
            foreach ($branch in @($branches)) {
                if ($dryRun) { Write-IlegnaLine ("Would delete merged branch '{0}'" -f $branch) Yellow; continue }
                Invoke-ExternalCommand -Name "git" -Arguments @("branch", "-d", $branch)
            }
        }
        default { throw "Unknown git command: $Subcommand" }
    }
}

try {
    if ($Interactive) { $CliArgs = @("-i") + @($CliArgs) }

    if ([string]::IsNullOrWhiteSpace($Resource)) {
        Show-Help
        return
    }

    if (Test-HelpRequest -Values @($Resource)) {
        Show-Help -HelpResource $Command
        return
    }

    if ((Test-HelpRequest -Values @($Command)) -or (Test-HelpRequest -Values $CliArgs)) {
        $normalizedHelpResource = ConvertTo-ResourceName -Value $Resource
        if ($normalizedHelpResource -in @("chezmoi", "task", "git")) {
            Show-Help -HelpResource $Resource
        }
        else {
            Invoke-LegacyIlegna -Arguments @($Resource, $Command) + @($CliArgs)
        }
        return
    }

    switch (ConvertTo-ResourceName -Value $Resource) {
        "chezmoi" { Invoke-ChezmoiResource -Subcommand $Command -InputArgs $CliArgs; break }
        "task" { Invoke-TaskResource -Subcommand $Command -InputArgs $CliArgs; break }
        "git" { Invoke-GitResource -Subcommand $Command -InputArgs $CliArgs; break }
        default { Invoke-LegacyIlegna -Arguments @($Resource, $Command) + @($CliArgs); break }
    }
}
catch {
    throw
}
