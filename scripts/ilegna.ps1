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
    param([string]$Resource)

    $normalizedResource = ConvertTo-IlegnaResourceName -Resource $Resource
    switch ($normalizedResource) {
        "wt" {
            @"
ilegna wt <command> [args]

Commands:
  list                         list worktrees
  new <branch> [--base main]   create a worktree
  remove <branch-or-path>      remove a worktree
  open <branch-or-path>        cd into a worktree
  status                       show status for each worktree
  prune                        prune stale worktree metadata

Examples:
  ilegna wt new feat/fun-cli --base main
  ilegna wt new -i
  ilegna wt open feat/fun-cli
"@
            return
        }
        "git-bare" {
            @"
ilegna git-bare <command> [args]

Commands:
  sync [branch|--all] [--tags] [--dry-run]   sync refs from a remote
  status [branch|--all]                      compare local and remote refs
  refs                                       list local bare refs
  path                                       print resolved bare repo path

Examples:
  ilegna git-bare sync main
  ilegna git-bare sync --all --tags
  ilegna git-bare status --all
"@
            return
        }
        "pr" {
            @"
ilegna pr <command> [args]

Commands:
  new [--target develop] [--ready]   create an Azure DevOps pull request
  list [raw az args]                 list pull requests
  view [raw az args]                 view pull request details
  checkout [raw az args]             checkout a pull request

Examples:
  ilegna pr new
  ilegna pr new --ready
  ilegna pr list --status active
"@
            return
        }
        "pipeline" {
            @"
ilegna pipeline <command> [args]

Commands:
  list [raw args]                         list recent runs
  watch <run-id>                          watch a run until completion
  open <run-id>                           open a run in the browser
  active|definitions [--repo name]        show enabled Azure pipelines for repo
  trigger|run|start [--id id] [--dry-run] queue an Azure pipeline
  approvals [--status pending]            list pending release approvals
  complete|approve --approval-id id       approve a release approval

Examples:
  ilegna pipeline list
  ilegna pipeline active
  ilegna pipeline trigger --dry-run
  ilegna pipeline complete --approval-id 123 --dry-run
"@
            return
        }
        "jira" {
            @"
ilegna jira <command> [args]

Commands:
  me                         show current Jira user
  mine [raw jira args]       list assigned issues
  start <ISSUE> [text]       start a local work timer
  show                       show active work timer
  stop [ISSUE] [--log|--no-log] stop timer, prompting to log/edit work time
  worklog <ISSUE> <time>       add a Jira worklog entry, for example 30m

Examples:
  ilegna jira mine
  ilegna jira start AL-1541 "investigate issue"
  ilegna jira show
  ilegna jira stop AL-1541
  ilegna jira worklog AL-1541 30m
"@
            return
        }
        "config" {
            @"
ilegna config <command> [args]

Commands:
  backup                    back up local Git/SSH config files
  list                      list available config backups
  restore <version|latest>  restore a backup

Examples:
  ilegna config backup
  ilegna config list
  ilegna config restore latest --items ssh
"@
            return
        }
        "doctor" {
            @"
ilegna doctor

Checks common local workflow tools such as git, chezmoi, mise, az, gh, jira, rtk, and opencode.

Example:
  ilegna doctor
"@
            return
        }
    }

    @"
ilegna <resource> <command> [args]

Resources:
  wt          git worktrees: list, new, remove, open, status, prune
  git-bare    bare repos: sync, status, refs, path
  pr          pull requests: new, list, view, checkout
  pipeline    CI runs: list, watch, open, active, trigger, approvals, complete
  jira        Jira helpers: me, mine, start, show, stop
  config      local config backups: backup, list, restore
  doctor      quick local environment check

Examples:
  ilegna wt new feat/fun-cli --base main
  ilegna wt new -i
  ilegna wt open feat/fun-cli
  ilegna git-bare sync main
  ilegna git-bare sync --all --tags
  ilegna pr new
  ilegna pipeline list
  ilegna pipeline active
  ilegna pipeline trigger --dry-run
  ilegna jira start ABC-123 "implement CLI"
  ilegna config backup
  ilegna config restore latest --items ssh
"@
}

function ConvertTo-IlegnaResourceName {
    [CmdletBinding()]
    param([string]$Resource)

    if ([string]::IsNullOrWhiteSpace($Resource)) {
        return $null 
    }

    switch ($Resource.ToLowerInvariant()) {
        { $_ -in @("wt", "worktree", "worktrees") } {
            return "wt" 
        }
        { $_ -in @("git-bare", "bare") } {
            return "git-bare" 
        }
        { $_ -in @("pr", "pull-request", "pull-requests") } {
            return "pr" 
        }
        { $_ -in @("pipeline", "pipelines", "ci") } {
            return "pipeline" 
        }
        "jira" {
            return "jira" 
        }
        "config" {
            return "config" 
        }
        "doctor" {
            return "doctor" 
        }
        default {
            return $Resource.ToLowerInvariant() 
        }
    }
}

function Test-IlegnaHelpRequest {
    [CmdletBinding()]
    param([AllowNull()][string[]]$Values)

    foreach ($value in @($Values)) {
        if ($value -in @("help", "-h", "--help")) {
            return $true 
        }
    }

    return $false
}

function Split-IlegnaArgs {
    [CmdletBinding()]
    param([string[]]$InputArgs)

    [string[]]$inputList = if ($null -eq $InputArgs) {
        @()
    }
    else {
        @($InputArgs)
    }
    $positionals = New-Object System.Collections.Generic.List[string]
    $options = @{}
    $flags = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

    for ($i = 0; $i -lt $inputList.Count; $i++) {
        $item = $inputList[$i]
        if ([string]::IsNullOrWhiteSpace($item)) {
            continue
        }

        $item = $item.ToString()
        if ($item.StartsWith("--")) {
            $name = $item.Substring(2)
            if ([string]::IsNullOrWhiteSpace($name)) {
                continue
            }

            $next = if ($i + 1 -lt $inputList.Count) {
                $inputList[$i + 1].ToString()
            }
            else {
                $null
            }
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
            if ([string]::IsNullOrWhiteSpace($name)) {
                continue
            }

            $next = if ($i + 1 -lt $inputList.Count) {
                $inputList[$i + 1].ToString()
            }
            else {
                $null
            }
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

function Assert-GitRepository {
    [CmdletBinding()]
    param()

    $inside = git rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0 -and $inside -and $inside.Trim() -eq "true") {
        return
    }

    $bare = git rev-parse --is-bare-repository 2>$null
    if ($LASTEXITCODE -eq 0 -and $bare -and $bare.Trim() -eq "true") {
        return
    }

    throw "Not inside a git repository."
}

function Get-GitRoot {
    [CmdletBinding()]
    param()

    Assert-GitRepository
    $root = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($root)) {
        $bareRoot = Get-GitBareRepositoryPathOrNull
        if (-not [string]::IsNullOrWhiteSpace($bareRoot)) {
            return $bareRoot
        }
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
    if ($LASTEXITCODE -eq 0) {
        return "main"
    }

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
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($remote)) {
        return "unknown"
    }

    if ($remote -match 'dev\.azure\.com|\.visualstudio\.com|azuredevops') {
        return "azure"
    }
    if ($remote -match 'github\.com[:/]') {
        return "github"
    }
    return "unknown"
}

function Test-GitBareRepositoryPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $isBare = git --git-dir $Path config --bool core.bare 2>$null
    return ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($isBare) -and $isBare.Trim() -eq "true")
}

function Resolve-GitBareRepositoryPath {
    [CmdletBinding()]
    param([string]$Path)

    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
        if (-not $resolved) {
            throw "Bare repo path not found: $Path"
        }

        $candidate = $resolved.ProviderPath
        if (-not (Test-GitBareRepositoryPath -Path $candidate)) {
            throw "Path is not a bare git repository: $candidate"
        }
        return $candidate
    }

    $isCurrentBare = git rev-parse --is-bare-repository 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($isCurrentBare) -and $isCurrentBare.Trim() -eq "true") {
        $gitDir = git rev-parse --git-dir 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitDir)) {
            $candidate = $gitDir.Trim()
            $resolved = Resolve-Path -LiteralPath $candidate -ErrorAction SilentlyContinue
            if ($resolved) {
                $candidate = $resolved.ProviderPath
            }
            if (Test-GitBareRepositoryPath -Path $candidate) {
                return $candidate
            }
        }
    }

    $commonDir = git rev-parse --git-common-dir 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($commonDir)) {
        $candidate = $commonDir.Trim()
        $resolved = Resolve-Path -LiteralPath $candidate -ErrorAction SilentlyContinue
        if (-not $resolved -and -not [System.IO.Path]::IsPathRooted($candidate)) {
            $root = git rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($root)) {
                $resolved = Resolve-Path -LiteralPath (Join-Path $root.Trim() $candidate) -ErrorAction SilentlyContinue
            }
        }

        if ($resolved) {
            $candidate = $resolved.ProviderPath
        }
        if (Test-GitBareRepositoryPath -Path $candidate) {
            return $candidate
        }
    }

    throw "Unable to resolve a bare repository. Run from a bare-backed worktree or pass --path <bare-repo>."
}

function Get-GitBareRepositoryPathOrNull {
    [CmdletBinding()]
    param()

    try {
        return Resolve-GitBareRepositoryPath
    }
    catch {
        return $null
    }
}

function Get-GitBareDefaultBranch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [Parameter(Mandatory)][string]$Remote
    )

    $remoteHead = git --git-dir $RepoPath ls-remote --symref $Remote HEAD 2>$null
    if ($LASTEXITCODE -eq 0) {
        foreach ($line in @($remoteHead)) {
            if ($line -match '^ref:\s+refs/heads/(.+)\s+HEAD$') {
                return $Matches[1]
            }
        }
    }

    $localHead = git --git-dir $RepoPath symbolic-ref --short HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($localHead)) {
        return $localHead.Trim()
    }

    return "main"
}

function Get-GitBareSelectedBranch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Parsed,
        [Parameter(Mandatory)][string]$RepoPath,
        [Parameter(Mandatory)][string]$Remote
    )

    $branch = Get-IlegnaOption -Parsed $Parsed -Names @("branch", "b")
    if ([string]::IsNullOrWhiteSpace($branch)) {
        $branch = @($Parsed.Positionals | Where-Object { $_ -ne "all" } | Select-Object -First 1) | Select-Object -First 1
    }

    if ([string]::IsNullOrWhiteSpace($branch)) {
        $branch = Get-GitBareDefaultBranch -RepoPath $RepoPath -Remote $Remote
    }
    if ([string]::IsNullOrWhiteSpace($branch)) {
        throw "Unable to resolve branch. Pass <branch> or --branch <name>."
    }

    return $branch
}

function Get-GitBareRemoteHeads {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [Parameter(Mandatory)][string]$Remote
    )

    $lines = git --git-dir $RepoPath ls-remote --heads $Remote 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to query remote heads from '$Remote'."
    }

    $heads = foreach ($line in @($lines)) {
        if ($line -match '^([0-9a-fA-F]+)\s+refs/heads/(.+)$') {
            [pscustomobject]@{
                Branch = $Matches[2]
                Sha = $Matches[1]
            }
        }
    }

    return @($heads)
}

function Get-GitBareRemoteBranchSha {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [Parameter(Mandatory)][string]$Remote,
        [Parameter(Mandatory)][string]$Branch
    )

    $escapedBranch = [regex]::Escape($Branch)
    $lines = git --git-dir $RepoPath ls-remote --heads $Remote $Branch 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to query remote branch '$Branch' from '$Remote'."
    }

    foreach ($line in @($lines)) {
        if ($line -match "^([0-9a-fA-F]+)\s+refs/heads/$escapedBranch$") {
            return $Matches[1]
        }
    }

    return $null
}

function Get-GitBareLocalBranchSha {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [Parameter(Mandatory)][string]$Branch
    )

    $sha = git --git-dir $RepoPath rev-parse --verify "refs/heads/$Branch" 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sha)) {
        return $null
    }

    return $sha.Trim()
}

function Write-GitBareBranchStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [Parameter(Mandatory)][string]$Remote,
        [Parameter(Mandatory)][string]$Branch,
        [string]$RemoteSha
    )

    $localSha = Get-GitBareLocalBranchSha -RepoPath $RepoPath -Branch $Branch
    if ([string]::IsNullOrWhiteSpace($RemoteSha)) {
        $RemoteSha = Get-GitBareRemoteBranchSha -RepoPath $RepoPath -Remote $Remote -Branch $Branch
    }

    $state = if ([string]::IsNullOrWhiteSpace($RemoteSha)) {
        "missing-remote"
    }
    elseif ([string]::IsNullOrWhiteSpace($localSha)) {
        "missing-local"
    }
    elseif ($localSha -eq $RemoteSha) {
        "up-to-date"
    }
    else {
        "stale"
    }

    $color = if ($state -eq "up-to-date") {
        [ConsoleColor]::Green
    }
    elseif ($state -eq "stale") {
        [ConsoleColor]::Yellow
    }
    else {
        [ConsoleColor]::Red
    }
    $localText = if ([string]::IsNullOrWhiteSpace($localSha)) {
        "<missing>"
    }
    else {
        $localSha
    }
    $remoteText = if ([string]::IsNullOrWhiteSpace($RemoteSha)) {
        "<missing>"
    }
    else {
        $RemoteSha
    }
    Write-IlegnaLine ("{0} local={1} remote={2} {3}" -f $Branch, $localText, $remoteText, $state) $color
}

function Get-GitBareWorktreeBranches {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepoPath)

    $branches = New-Object 'System.Collections.Generic.Dictionary[string,string]'
    $currentPath = $null
    foreach ($line in git --git-dir $RepoPath worktree list --porcelain) {
        if ($line -match '^worktree\s+(.+)$') {
            $currentPath = $Matches[1]
            continue
        }

        if ($line -match '^branch\s+refs/heads/(.+)$' -and -not [string]::IsNullOrWhiteSpace($currentPath)) {
            $branches[$Matches[1]] = $currentPath
        }
    }

    return $branches
}

function Get-GitBareLocalBranches {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepoPath)

    $branches = git --git-dir $RepoPath for-each-ref --format="%(refname:short)" refs/heads 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to list local branches in '$RepoPath'."
    }

    return @($branches | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Sync-GitBareBranch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [Parameter(Mandatory)][string]$Remote,
        [Parameter(Mandatory)][string]$Branch,
        [string]$WorktreePath,
        [switch]$DryRun
    )

    if (-not [string]::IsNullOrWhiteSpace($WorktreePath)) {
        Write-IlegnaLine "Syncing checked-out branch '$Branch' via worktree '$WorktreePath'" Cyan
        $worktreeArgs = if ($DryRun) {
            @("-C", $WorktreePath, "fetch", "--dry-run", $Remote, $Branch)
        }
        else {
            @("-C", $WorktreePath, "pull", "--ff-only", $Remote, $Branch)
        }

        git @worktreeArgs
        if ($LASTEXITCODE -ne 0) {
            throw "git worktree sync failed for '$Branch'."
        }
        return
    }

    $refspec = "+refs/heads/${Branch}:refs/heads/${Branch}"
    $fetchArgs = @("--git-dir", $RepoPath, "fetch", "--prune")
    if ($DryRun) {
        $fetchArgs += "--dry-run"
    }
    $fetchArgs += $Remote
    $fetchArgs += $refspec

    Write-IlegnaLine "Syncing bare branch '$Branch'" Cyan
    git @fetchArgs
    if ($LASTEXITCODE -ne 0) {
        throw "git fetch failed for '$Branch'."
    }
}

function Sync-GitBareTags {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [Parameter(Mandatory)][string]$Remote,
        [switch]$DryRun
    )

    $fetchArgs = @("--git-dir", $RepoPath, "fetch", "--prune", "--prune-tags")
    if ($DryRun) {
        $fetchArgs += "--dry-run"
    }
    $fetchArgs += $Remote
    $fetchArgs += "+refs/tags/*:refs/tags/*"

    Write-IlegnaLine "Syncing bare tags" Cyan
    git @fetchArgs
    if ($LASTEXITCODE -ne 0) {
        throw "git tag fetch failed."
    }
}

function Remove-GitBareDeletedBranches {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [Parameter(Mandatory)][object[]]$RemoteHeads,
        [Parameter(Mandatory)][object]$WorktreeBranches,
        [switch]$DryRun
    )

    $remoteBranchSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    foreach ($head in $RemoteHeads) {
        $remoteBranchSet.Add($head.Branch) | Out-Null
    }

    foreach ($branch in Get-GitBareLocalBranches -RepoPath $RepoPath) {
        if ($remoteBranchSet.Contains($branch)) {
            continue
        }

        if ($WorktreeBranches.ContainsKey($branch)) {
            Write-IlegnaLine "Skipping prune for checked-out branch '$branch' at '$($WorktreeBranches[$branch])'" Yellow
            continue
        }

        $message = if ($DryRun) {
            "Would prune local branch '$branch'"
        }
        else {
            "Pruning local branch '$branch'"
        }
        Write-IlegnaLine $message Yellow
        if ($DryRun) {
            continue
        }

        git --git-dir $RepoPath update-ref -d "refs/heads/$branch"
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to prune local branch '$branch'."
        }
    }
}

function Invoke-IlegnaGitBare {
    [CmdletBinding()]
    param(
        [string]$Subcommand,
        [string[]]$InputArgs
    )

    if ([string]::IsNullOrWhiteSpace($Subcommand)) {
        $Subcommand = "status"
    }
    $parsed = Split-IlegnaArgs -InputArgs $InputArgs
    $repoPath = Resolve-GitBareRepositoryPath -Path (Get-IlegnaOption -Parsed $parsed -Names @("path", "repo", "git-dir", "bare"))
    $remote = Get-IlegnaOption -Parsed $parsed -Names @("remote", "r") -Default "origin"
    $all = (Test-IlegnaFlag -Parsed $parsed -Names @("all")) -or (@($parsed.Positionals | Select-Object -First 1) -eq "all")

    switch ($Subcommand.ToLowerInvariant()) {
        "path" {
            Write-IlegnaLine $repoPath Cyan
        }
        { $_ -in @("sync", "fetch", "update") } {
            $syncTags = Test-IlegnaFlag -Parsed $parsed -Names @("tags")
            $dryRun = Test-IlegnaFlag -Parsed $parsed -Names @("dry-run", "no-op")
            $worktreeBranches = Get-GitBareWorktreeBranches -RepoPath $repoPath

            if ($all) {
                Write-IlegnaLine "Syncing bare repo '$repoPath' from '$remote' (all branches)" Cyan
                $heads = Get-GitBareRemoteHeads -RepoPath $repoPath -Remote $remote
                foreach ($head in @($heads | Sort-Object Branch)) {
                    $worktreePath = if ($worktreeBranches.ContainsKey($head.Branch)) {
                        $worktreeBranches[$head.Branch]
                    }
                    else {
                        $null
                    }
                    Sync-GitBareBranch -RepoPath $repoPath -Remote $remote -Branch $head.Branch -WorktreePath $worktreePath -DryRun:$dryRun
                }

                Remove-GitBareDeletedBranches -RepoPath $repoPath -RemoteHeads $heads -WorktreeBranches $worktreeBranches -DryRun:$dryRun
            }
            else {
                $branch = Get-GitBareSelectedBranch -Parsed $parsed -RepoPath $repoPath -Remote $remote
                $worktreePath = if ($worktreeBranches.ContainsKey($branch)) {
                    $worktreeBranches[$branch]
                }
                else {
                    $null
                }
                Write-IlegnaLine "Syncing bare repo '$repoPath' from '$remote' (branch '$branch')" Cyan
                Sync-GitBareBranch -RepoPath $repoPath -Remote $remote -Branch $branch -WorktreePath $worktreePath -DryRun:$dryRun
            }

            if ($syncTags) {
                Sync-GitBareTags -RepoPath $repoPath -Remote $remote -DryRun:$dryRun
            }

            if ($dryRun) {
                Write-IlegnaLine "Dry-run complete." Yellow; return
            }
            Write-IlegnaLine "Bare repo refs synced." Green
        }
        { $_ -in @("status", "verify", "check") } {
            Write-IlegnaLine "repo=$repoPath" Cyan
            Write-IlegnaLine "remote=$remote" Cyan

            if ($all) {
                $heads = Get-GitBareRemoteHeads -RepoPath $repoPath -Remote $remote
                if (-not $heads) {
                    Write-IlegnaLine "No remote heads found." Yellow; return
                }
                foreach ($head in @($heads | Sort-Object Branch)) {
                    Write-GitBareBranchStatus -RepoPath $repoPath -Remote $remote -Branch $head.Branch -RemoteSha $head.Sha
                }
                return
            }

            $branch = Get-GitBareSelectedBranch -Parsed $parsed -RepoPath $repoPath -Remote $remote
            Write-GitBareBranchStatus -RepoPath $repoPath -Remote $remote -Branch $branch
        }
        { $_ -in @("refs", "list") } {
            git --git-dir $repoPath for-each-ref --sort=refname --format="%(refname:short) %(objectname:short) %(committerdate:relative)" refs/heads
        }
        default {
            throw "Unknown git-bare command: $Subcommand"
        }
    }
}

function Get-WorktreePathByBranch {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Branch)

    $currentPath = $null
    $currentBranch = $null
    foreach ($line in git worktree list --porcelain) {
        if ($line -match '^worktree\s+(.+)$') {
            if ($currentPath -and $currentBranch -eq $Branch) {
                return $currentPath
            }
            $currentPath = $Matches[1]
            $currentBranch = $null
            continue
        }

        if ($line -match '^branch\s+refs/heads/(.+)$') {
            $currentBranch = $Matches[1]
        }
    }

    if ($currentPath -and $currentBranch -eq $Branch) {
        return $currentPath
    }
    return $null
}

function Convert-BranchToWorktreeName {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Branch)

    return ($Branch -replace '[^A-Za-z0-9._-]', '-')
}

function Get-DefaultWorktreeParent {
    [CmdletBinding()]
    param()

    $bareRoot = Get-GitBareRepositoryPathOrNull
    if (-not [string]::IsNullOrWhiteSpace($bareRoot)) {
        return $bareRoot
    }

    return (Join-Path (Get-GitRoot) ".worktrees")
}

function Get-DefaultWorktreePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Branch,
        [switch]$CurrentDirectory
    )

    $parent = if ($CurrentDirectory) {
        (Get-Location).ProviderPath
    }
    else {
        Get-DefaultWorktreeParent
    }
    return (Join-Path $parent (Convert-BranchToWorktreeName -Branch $Branch))
}

function Resolve-WorktreePathInput {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $expanded = $ExecutionContext.InvokeCommand.ExpandString($Path)
    if ([System.IO.Path]::IsPathRooted($expanded)) {
        return $expanded
    }

    return (Join-Path (Get-Location).ProviderPath $expanded)
}

function Read-IlegnaPrompt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [string]$Default
    )

    $label = if ([string]::IsNullOrWhiteSpace($Default)) {
        $Prompt
    }
    else {
        "$Prompt [$Default]"
    }
    $value = Read-Host $label
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default
    }
    return $value.Trim()
}

function Read-IlegnaYesNo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [bool]$Default = $true
    )

    $suffix = if ($Default) {
        "Y/n"
    }
    else {
        "y/N"
    }
    $value = Read-Host "$Prompt [$suffix]"
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default
    }

    return ($value.Trim().ToLowerInvariant() -in @("y", "yes", "s", "sim"))
}

function Resolve-WorktreeBaseRef {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Base)

    git fetch origin $Base *> $null
    if ($LASTEXITCODE -eq 0) {
        return "FETCH_HEAD"
    }

    git rev-parse --verify "$Base^{commit}" *> $null
    if ($LASTEXITCODE -eq 0) {
        return $Base
    }

    throw "Unable to resolve base ref: $Base"
}

function Invoke-IlegnaWorktree {
    [CmdletBinding()]
    param(
        [string]$Subcommand,
        [string[]]$InputArgs
    )

    if ([string]::IsNullOrWhiteSpace($Subcommand)) {
        $Subcommand = "list"
    }
    $parsed = Split-IlegnaArgs -InputArgs $InputArgs

    switch ($Subcommand.ToLowerInvariant()) {
        "list" {
            Assert-GitRepository
            git worktree list
        }
        "new" {
            Assert-GitRepository
            $interactive = Test-IlegnaFlag -Parsed $parsed -Names @("interactive", "i")
            $branch = $parsed.Positionals | Select-Object -First 1

            if ($interactive -and [string]::IsNullOrWhiteSpace($branch)) {
                $branch = Read-IlegnaPrompt -Prompt "Branch"
            }

            if ([string]::IsNullOrWhiteSpace($branch)) {
                throw "Usage: ilegna wt new <branch> [--base main] [--path .worktrees/name] [--cd] or ilegna wt new -i"
            }

            git check-ref-format --branch $branch *> $null
            if ($LASTEXITCODE -ne 0) {
                throw "Invalid branch name: $branch"
            }

            $base = Get-IlegnaOption -Parsed $parsed -Names @("base", "b") -Default (Get-DefaultBranch)
            $path = Get-IlegnaOption -Parsed $parsed -Names @("path", "location", "name")
            $cdAfter = Test-IlegnaFlag -Parsed $parsed -Names @("cd", "open")

            if ($interactive) {
                $base = Read-IlegnaPrompt -Prompt "Base" -Default $base
                $defaultPath = Get-DefaultWorktreePath -Branch $branch -CurrentDirectory
                $path = Read-IlegnaPrompt -Prompt "Location/Name" -Default $defaultPath
                $cdAfter = Read-IlegnaYesNo -Prompt "Move to worktree directory" -Default $true
            }

            if ([string]::IsNullOrWhiteSpace($path)) {
                $path = Get-DefaultWorktreePath -Branch $branch
            }

            $path = Resolve-WorktreePathInput -Path $path

            $parent = Split-Path -Parent $path
            if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }

            if (Test-Path $path) {
                throw "Worktree path already exists: $path"
            }

            Write-IlegnaLine "Creating worktree '$branch' from '$base'" Cyan
            $baseRef = Resolve-WorktreeBaseRef -Base $base

            git worktree add $path -b $branch $baseRef
            if ($LASTEXITCODE -ne 0) {
                throw "git worktree add failed."
            }

            Write-IlegnaLine "Worktree ready: $path" Green
            if ($cdAfter) {
                Set-Location $path
            }
        }
        "remove" {
            Assert-GitRepository
            $target = $parsed.Positionals | Select-Object -First 1
            if ([string]::IsNullOrWhiteSpace($target)) {
                throw "Usage: ilegna wt remove <branch-or-path> [--force]"
            }

            $path = if (Test-Path $target) {
                $target
            }
            else {
                Get-WorktreePathByBranch -Branch $target
            }
            if ([string]::IsNullOrWhiteSpace($path)) {
                throw "Worktree not found: $target"
            }

            $force = Test-IlegnaFlag -Parsed $parsed -Names @("force", "f")
            $status = git -C $path status --porcelain 2>$null
            if ($status -and -not $force) {
                Write-IlegnaLine "Worktree has local changes:" Yellow
                $status | ForEach-Object { Write-IlegnaLine "  $_" Yellow }
                throw "Use --force if you really want to remove it."
            }

            $removeArgs = @("worktree", "remove", $path)
            if ($force) {
                $removeArgs += "--force"
            }
            git @removeArgs
            if ($LASTEXITCODE -ne 0) {
                throw "git worktree remove failed."
            }
        }
        { $_ -in @("open", "cd") } {
            Assert-GitRepository
            $target = $parsed.Positionals | Select-Object -First 1
            if ([string]::IsNullOrWhiteSpace($target)) {
                throw "Usage: ilegna wt open <branch-or-path>"
            }

            $path = if (Test-Path $target) {
                $target
            }
            else {
                Get-WorktreePathByBranch -Branch $target
            }
            if ([string]::IsNullOrWhiteSpace($path)) {
                throw "Worktree not found: $target"
            }
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

    if ([string]::IsNullOrWhiteSpace($Subcommand)) {
        $Subcommand = "list"
    }
    $parsed = Split-IlegnaArgs -InputArgs $InputArgs

    function Assert-AzureCli {
        if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
            throw "Azure CLI not found. Install az and the azure-devops extension to use ilegna pr."
        }
    }

    function Get-PullRequestId {
        $id = Get-IlegnaOption -Parsed $parsed -Names @("id", "pr")
        if (-not [string]::IsNullOrWhiteSpace($id)) {
            return $id
        }
        return ($parsed.Positionals | Select-Object -First 1)
    }

    switch ($Subcommand.ToLowerInvariant()) {
        { $_ -in @("new", "create") } {
            Assert-GitRepository
            Assert-AzureCli

            $base = Get-IlegnaOption -Parsed $parsed -Names @("base", "target") -Default "develop"
            $title = Get-IlegnaOption -Parsed $parsed -Names @("title")
            $body = Get-IlegnaOption -Parsed $parsed -Names @("body")
            $draft = -not (Test-IlegnaFlag -Parsed $parsed -Names @("ready", "no-draft"))
            $currentBranch = Get-CurrentBranch
            if ([string]::IsNullOrWhiteSpace($currentBranch)) {
                throw "Unable to resolve current branch."
            }

            if ([string]::IsNullOrWhiteSpace($title)) {
                $title = $currentBranch
            }
            $azArgs = @("repos", "pr", "create", "--source-branch", $currentBranch, "--target-branch", $base, "--title", $title, "--draft", $draft.ToString().ToLowerInvariant())
            if ($body) {
                $azArgs += @("--description", $body)
            }
            az @azArgs
        }
        "list" {
            Assert-AzureCli
            az repos pr list @InputArgs
        }
        { $_ -in @("view", "show", "open") } {
            Assert-AzureCli
            $id = Get-PullRequestId
            if ([string]::IsNullOrWhiteSpace($id)) {
                throw "Usage: ilegna pr view <id> [--open]"
            }

            $azArgs = @("repos", "pr", "show", "--id", $id)
            if ($Subcommand.ToLowerInvariant() -eq "open" -or (Test-IlegnaFlag -Parsed $parsed -Names @("open", "web"))) {
                $azArgs += "--open"
            }
            az @azArgs
        }
        "checkout" {
            Assert-AzureCli
            $id = Get-PullRequestId
            if ([string]::IsNullOrWhiteSpace($id)) {
                throw "Usage: ilegna pr checkout <id>"
            }
            az repos pr checkout --id $id
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

    if ([string]::IsNullOrWhiteSpace($Subcommand)) {
        $Subcommand = "list"
    }
    $hostName = Get-RepositoryHost
    $parsed = Split-IlegnaArgs -InputArgs $InputArgs

    function Assert-AzureCli {
        if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
            throw "Azure CLI not found. Install az and the azure-devops extension to use Azure Pipelines commands."
        }
    }

    function Get-PipelineRunId {
        $id = Get-IlegnaOption -Parsed $parsed -Names @("id", "run")
        if (-not [string]::IsNullOrWhiteSpace($id)) {
            return $id
        }
        return ($parsed.Positionals | Select-Object -First 1)
    }

    function Get-AzureDevOpsRemoteUrl {
        $remote = git remote get-url origin 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($remote)) {
            return $remote.Trim()
        }
        return $null
    }

    function Get-AzureDevOpsProjectName {
        $project = Get-IlegnaOption -Parsed $parsed -Names @("project", "p")
        if (-not [string]::IsNullOrWhiteSpace($project)) {
            return $project
        }

        $remote = Get-AzureDevOpsRemoteUrl
        if ([string]::IsNullOrWhiteSpace($remote)) {
            return $null
        }

        if ($remote -match '/([^/]+)/_git/[^/]+/?$') {
            return [uri]::UnescapeDataString($Matches[1])
        }
        if ($remote -match '/v3/[^/]+/([^/]+)/[^/]+/?$') {
            return [uri]::UnescapeDataString($Matches[1])
        }
        return $null
    }

    function Get-AzurePipelineRepositoryName {
        param([switch]$AllowPositional)

        $repo = Get-IlegnaOption -Parsed $parsed -Names @("repo", "repository", "r")
        if ([string]::IsNullOrWhiteSpace($repo) -and $AllowPositional) {
            $repo = $parsed.Positionals | Select-Object -First 1
        }

        if (-not [string]::IsNullOrWhiteSpace($repo)) {
            return $repo
        }

        $remote = Get-AzureDevOpsRemoteUrl
        if ([string]::IsNullOrWhiteSpace($remote)) {
            throw "Unable to resolve repository. Pass --repo <name>."
        }

        if ($remote -match '/_git/([^/]+?)(?:\.git)?/?$') {
            return [uri]::UnescapeDataString($Matches[1])
        }
        if ($remote -match '/v3/[^/]+/[^/]+/([^/]+?)(?:\.git)?/?$') {
            return [uri]::UnescapeDataString($Matches[1])
        }
        throw "Unable to resolve Azure repository from origin. Pass --repo <name>."
    }

    function Get-AzurePipelineRepositoryType {
        Get-IlegnaOption -Parsed $parsed -Names @("repo-type", "repository-type") -Default "tfsgit"
    }

    function Get-AzurePipelineDefinitions {
        param(
            [Parameter(Mandatory)][string]$Repository,
            [Parameter(Mandatory)][string]$RepositoryType,
            [string]$Name
        )

        $azArgs = @("pipelines", "list", "--repository", $Repository, "--repository-type", $RepositoryType, "--query-order", "ModifiedDesc", "-o", "json")
        if (-not [string]::IsNullOrWhiteSpace($Name)) {
            $azArgs += @("--name", $Name)
        }

        $json = az @azArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to list Azure pipelines for repository '$Repository'."
        }
        if ([string]::IsNullOrWhiteSpace(($json | Out-String))) {
            return @()
        }

        $definitions = ($json | Out-String) | ConvertFrom-Json
        return @($definitions)
    }

    function Select-AzureEnabledPipelineDefinitions {
        param([object[]]$Definitions)

        $enabled = @()
        foreach ($definition in @($Definitions)) {
            $hasEnabledStatus = $definition.queueStatus -eq "enabled" -or $definition.status -eq "enabled"
            $hasNoStatus = [string]::IsNullOrWhiteSpace($definition.queueStatus) -and [string]::IsNullOrWhiteSpace($definition.status)
            if ($hasEnabledStatus -or $hasNoStatus) {
                $enabled += $definition
            }
        }

        return @($enabled)
    }

    function Write-AzurePipelineDefinitions {
        param([object[]]$Definitions)

        if (-not $Definitions -or $Definitions.Count -eq 0) {
            Write-IlegnaLine "No matching Azure pipelines found." Yellow
            return
        }

        foreach ($definition in @($Definitions)) {
            $details = $definition
            if ($definition.id -and -not $definition.repository) {
                $detailsJson = az pipelines show --id $definition.id -o json 2>$null
                if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($detailsJson | Out-String))) {
                    $details = ($detailsJson | Out-String) | ConvertFrom-Json
                }
            }

            $status = if ($details.queueStatus) {
                $details.queueStatus
            }
            elseif ($details.status) {
                $details.status
            }
            else {
                "unknown"
            }
            $repo = if ($details.repository.name) {
                $details.repository.name
            }
            else {
                "unknown"
            }
            $yaml = if ($details.process.yamlFilename) {
                $details.process.yamlFilename
            }
            else {
                "<classic>"
            }
            Write-IlegnaLine ("{0} {1} status={2} repo={3} yaml={4}" -f $details.id, $details.name, $status, $repo, $yaml) Cyan
        }
    }

    function Resolve-AzurePipelineDefinition {
        param([switch]$AllowPositionalRepository)

        $id = Get-IlegnaOption -Parsed $parsed -Names @("id", "pipeline-id")
        if (-not [string]::IsNullOrWhiteSpace($id)) {
            $json = az pipelines show --id $id -o json
            if ($LASTEXITCODE -ne 0) {
                throw "Unable to resolve Azure pipeline id '$id'."
            }
            return (($json | Out-String) | ConvertFrom-Json)
        }

        $name = Get-IlegnaOption -Parsed $parsed -Names @("name", "pipeline")
        $repo = Get-AzurePipelineRepositoryName -AllowPositional:$AllowPositionalRepository
        $repoType = Get-AzurePipelineRepositoryType
        $definitions = @(Get-AzurePipelineDefinitions -Repository $repo -RepositoryType $repoType -Name $name)
        $enabled = @(Select-AzureEnabledPipelineDefinitions -Definitions $definitions)

        if (-not $enabled -or $enabled.Count -eq 0) {
            Write-AzurePipelineDefinitions -Definitions $definitions
            throw "No enabled Azure pipeline found for repository '$repo'. Pass --id <pipeline-id> or --name <pipeline-name>."
        }

        if ($enabled.Count -gt 1) {
            Write-AzurePipelineDefinitions -Definitions $enabled
            throw "Multiple enabled Azure pipelines found for repository '$repo'. Pass --id <pipeline-id> or --name <pipeline-name>."
        }

        return $enabled[0]
    }

    function Get-AzurePipelineBranch {
        $branch = Get-IlegnaOption -Parsed $parsed -Names @("branch", "b")
        if (-not [string]::IsNullOrWhiteSpace($branch)) {
            return $branch
        }

        $currentBranch = Get-CurrentBranch
        if (-not [string]::IsNullOrWhiteSpace($currentBranch)) {
            return $currentBranch
        }
        return $null
    }

    function Invoke-AzurePipelineApprovals {
        param([switch]$Approve)

        Assert-AzureCli
        $project = Get-AzureDevOpsProjectName
        $approvalId = Get-IlegnaOption -Parsed $parsed -Names @("approval-id", "approval", "id")
        if ([string]::IsNullOrWhiteSpace($approvalId)) {
            $approvalId = $parsed.Positionals | Select-Object -First 1
        }

        $apiVersion = Get-IlegnaOption -Parsed $parsed -Names @("api-version") -Default "7.0"
        $azArgs = @("devops", "invoke", "--area", "release", "--resource", "approvals", "--api-version", $apiVersion, "-o", "json")
        if (-not [string]::IsNullOrWhiteSpace($project)) {
            $azArgs += @("--route-parameters", "project=$project")
        }

        if (-not $Approve -or [string]::IsNullOrWhiteSpace($approvalId)) {
            $statusFilter = Get-IlegnaOption -Parsed $parsed -Names @("status", "status-filter") -Default "pending"
            $listArgs = @($azArgs + @("--query-parameters", "statusFilter=$statusFilter"))
            az @listArgs
            if ($LASTEXITCODE -ne 0) {
                throw "Unable to list Azure DevOps release approvals through az devops invoke."
            }
            if ($Approve) {
                throw "Pass an approval id: ilegna pipeline complete --approval-id <id> [--comment <text>]"
            }
            return
        }

        $comment = Get-IlegnaOption -Parsed $parsed -Names @("comment", "message") -Default "Approved by ilegna pipeline complete"
        $status = Get-IlegnaOption -Parsed $parsed -Names @("status") -Default "approved"
        $payload = @{
            status = $status
            comments = $comment
        } | ConvertTo-Json -Depth 5
        $patchArgs = @($azArgs + @("--http-method", "PATCH", "--query-parameters", "approvalId=$approvalId"))
        if (Test-IlegnaFlag -Parsed $parsed -Names @("dry-run", "whatif")) {
            Write-IlegnaLine ("az {0} --in-file <payload>" -f ($patchArgs -join " ")) DarkGray
            Write-IlegnaLine $payload DarkGray
            return
        }

        $tempFile = New-TemporaryFile

        try {
            Set-Content -LiteralPath $tempFile.FullName -Value $payload -Encoding UTF8
            az @($patchArgs + @("--in-file", $tempFile.FullName))
            if ($LASTEXITCODE -ne 0) {
                throw "Unable to update Azure DevOps release approval '$approvalId'."
            }
        }
        finally {
            Remove-Item -LiteralPath $tempFile.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    switch ($Subcommand.ToLowerInvariant()) {
        { $_ -in @("active", "definitions") } {
            if ($hostName -ne "azure") {
                throw "Pipeline discovery by repository is only implemented for Azure DevOps repositories."
            }
            Assert-AzureCli

            $repo = Get-AzurePipelineRepositoryName -AllowPositional
            $repoType = Get-AzurePipelineRepositoryType
            $name = Get-IlegnaOption -Parsed $parsed -Names @("name", "pipeline")
            $definitions = @(Get-AzurePipelineDefinitions -Repository $repo -RepositoryType $repoType -Name $name)
            $enabled = @(Select-AzureEnabledPipelineDefinitions -Definitions $definitions)
            Write-AzurePipelineDefinitions -Definitions $enabled
        }
        { $_ -in @("trigger", "run", "start") } {
            if ($hostName -ne "azure") {
                throw "Pipeline trigger is only implemented for Azure DevOps repositories."
            }
            Assert-AzureCli

            $pipeline = Resolve-AzurePipelineDefinition -AllowPositionalRepository
            $azArgs = @("pipelines", "run", "--id", $pipeline.id)
            $branch = Get-AzurePipelineBranch
            if (-not [string]::IsNullOrWhiteSpace($branch)) {
                $azArgs += @("--branch", $branch)
            }

            $variables = Get-IlegnaOption -Parsed $parsed -Names @("variables", "vars")
            if (-not [string]::IsNullOrWhiteSpace($variables)) {
                $azArgs += @("--variables") + @($variables -split ",")
            }

            $parameters = Get-IlegnaOption -Parsed $parsed -Names @("parameters", "params")
            if (-not [string]::IsNullOrWhiteSpace($parameters)) {
                $azArgs += @("--parameters") + @($parameters -split ",")
            }

            if (Test-IlegnaFlag -Parsed $parsed -Names @("open", "web")) {
                $azArgs += "--open"
            }
            Write-IlegnaLine ("Queueing Azure pipeline {0} ({1})" -f $pipeline.id, $pipeline.name) Cyan
            if (Test-IlegnaFlag -Parsed $parsed -Names @("dry-run", "whatif")) {
                Write-IlegnaLine ("az {0}" -f ($azArgs -join " ")) DarkGray
                return
            }

            az @azArgs
        }
        "approvals" {
            Invoke-AzurePipelineApprovals
        }
        { $_ -in @("complete", "approve") } {
            Invoke-AzurePipelineApprovals -Approve
        }
        "list" {
            if ($hostName -eq "azure") {
                if (Get-Command az -ErrorAction SilentlyContinue) {
                    az pipelines runs list @InputArgs; return
                }
                throw "This looks like an Azure repo, but az was not found."
            }
            if ($hostName -eq "github") {
                if (Get-Command gh -ErrorAction SilentlyContinue) {
                    gh run list @InputArgs; return
                }
                throw "This looks like a GitHub repo, but gh was not found."
            }
            if (Get-Command gh -ErrorAction SilentlyContinue) {
                gh run list @InputArgs; return
            }
            if (Get-Command az -ErrorAction SilentlyContinue) {
                az pipelines runs list @InputArgs; return
            }
            throw "Install gh or az to list pipeline runs."
        }
        "watch" {
            if ($hostName -eq "azure") {
                if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
                    throw "This looks like an Azure repo, but az was not found."
                }
                $runId = Get-PipelineRunId
                if ([string]::IsNullOrWhiteSpace($runId)) {
                    throw "Usage: ilegna pipeline watch <run-id>"
                }

                while ($true) {
                    $run = az pipelines runs show --id $runId --query "{id:id,status:status,result:result,branch:sourceBranch}" -o json | ConvertFrom-Json
                    Write-IlegnaLine ("{0} status={1} result={2} branch={3}" -f $run.id, $run.status, $run.result, $run.branch) Cyan
                    if ($run.status -eq "completed") {
                        return
                    }
                    Start-Sleep -Seconds 10
                }
            }

            if (Get-Command gh -ErrorAction SilentlyContinue) {
                gh run watch @InputArgs; return
            }
            throw "Install gh to watch GitHub Actions runs."
        }
        { $_ -in @("open", "view") } {
            if ($hostName -eq "azure") {
                if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
                    throw "This looks like an Azure repo, but az was not found."
                }
                $runId = Get-PipelineRunId
                if ([string]::IsNullOrWhiteSpace($runId)) {
                    throw "Usage: ilegna pipeline open <run-id>"
                }
                az pipelines runs show --id $runId --open
                return
            }

            if (Get-Command gh -ErrorAction SilentlyContinue) {
                gh run view --web @InputArgs; return
            }
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

    $base = if ($env:LOCALAPPDATA) {
        $env:LOCALAPPDATA
    }
    else {
        Join-Path $HOME ".local\share"
    }
    $root = Join-Path $base "ilegna"
    if (-not (Test-Path $root)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }
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
    if (-not (Test-Path $path)) {
        return $null
    }
    Get-Content -Path $path -Raw | ConvertFrom-Json
}

function ConvertFrom-IlegnaTimerStartedAt {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "Jira timer startedAt is empty."
    }

    $parsed = [datetime]::MinValue
    $roundtripStyles = [System.Globalization.DateTimeStyles]::AllowWhiteSpaces -bor [System.Globalization.DateTimeStyles]::RoundtripKind
    if ([datetime]::TryParseExact($Value, "o", [System.Globalization.CultureInfo]::InvariantCulture, $roundtripStyles, [ref]$parsed)) {
        return $parsed
    }

    $styles = [System.Globalization.DateTimeStyles]::AllowWhiteSpaces -bor [System.Globalization.DateTimeStyles]::AssumeLocal
    $cultures = @(
        [System.Globalization.CultureInfo]::CurrentCulture,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.CultureInfo]::GetCultureInfo("en-US"),
        [System.Globalization.CultureInfo]::GetCultureInfo("pt-BR")
    )

    if ($Value -match '^\s*(\d{1,2})/(\d{1,2})/') {
        $first = [int]$Matches[1]
        $second = [int]$Matches[2]
        if ($second -gt 12) {
            $cultures = @(
                [System.Globalization.CultureInfo]::GetCultureInfo("en-US"),
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.CultureInfo]::CurrentCulture,
                [System.Globalization.CultureInfo]::GetCultureInfo("pt-BR")
            )
        }
        elseif ($first -gt 12) {
            $cultures = @(
                [System.Globalization.CultureInfo]::GetCultureInfo("pt-BR"),
                [System.Globalization.CultureInfo]::CurrentCulture,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.CultureInfo]::GetCultureInfo("en-US")
            )
        }
    }

    foreach ($culture in $cultures) {
        if ([datetime]::TryParse($Value, $culture, $styles, [ref]$parsed)) {
            return $parsed
        }
    }

    throw "Unable to parse Jira timer startedAt '$Value'. Start a new timer with: ilegna jira start <ISSUE> [description]"
}

function Resolve-IlegnaJiraCli {
    [CmdletBinding()]
    param()

    $candidates = @(
        $env:WINDOTS_JIRA_CLI,
        $env:JIRA_CLI,
        "C:\tools\jira-cli\jira.exe"
    )

    if ($env:LOCALAPPDATA) {
        $candidates += (Join-Path $env:LOCALAPPDATA "Programs\jira-cli\jira.exe")
    }

    foreach ($candidate in @($candidates)) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    $command = Get-Command jira -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw "jira CLI not found. Install ankitpokhrel/jira-cli or place jira.exe in C:\tools\jira-cli."
}

function Invoke-IlegnaJiraCli {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$Arguments)

    $jiraPath = Resolve-IlegnaJiraCli
    & $jiraPath @Arguments
}

function ConvertTo-IlegnaJiraDuration {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Value)

    $trimmed = $Value.Trim().ToLowerInvariant()
    if ($trimmed -notmatch '^(?:[1-9]\d*\s*[wdhm])(?:\s+[1-9]\d*\s*[wdhm])*$') {
        throw "Invalid Jira duration '$Value'. Use Jira format like 30m, 1h, 1h 30m, 2d, or 1w 2d 3h 30m."
    }

    $unitOrder = @{ w = 1; d = 2; h = 3; m = 4 }
    $lastOrder = 0
    $tokens = @()

    foreach ($match in [regex]::Matches($trimmed, '([1-9]\d*)\s*([wdhm])')) {
        $unit = $match.Groups[2].Value
        $order = $unitOrder[$unit]
        if ($order -le $lastOrder) {
            throw "Invalid Jira duration '$Value'. Use each unit once, in order: w d h m."
        }

        $lastOrder = $order
        $tokens += ("{0}{1}" -f $match.Groups[1].Value, $unit)
    }

    return ($tokens -join " ")
}

function Read-IlegnaJiraDuration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [Parameter(Mandatory)][string]$Default
    )

    while ($true) {
        $value = Read-IlegnaPrompt -Prompt $Prompt -Default $Default
        try {
            return (ConvertTo-IlegnaJiraDuration -Value $value)
        }
        catch {
            Write-IlegnaLine $_.Exception.Message Yellow
        }
    }
}

function Add-IlegnaJiraWorklog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Issue,
        [Parameter(Mandatory)][string]$Duration,
        [Parameter(Mandatory)][string]$Comment
    )

    Invoke-IlegnaJiraCli -Arguments @("issue", "worklog", "add", $Issue, $Duration, "--comment", $Comment, "--no-input")
}

function Invoke-IlegnaJira {
    [CmdletBinding()]
    param(
        [string]$Subcommand,
        [string[]]$InputArgs
    )

    if ([string]::IsNullOrWhiteSpace($Subcommand)) {
        $Subcommand = "mine"
    }
    $parsed = Split-IlegnaArgs -InputArgs $InputArgs

    switch ($Subcommand.ToLowerInvariant()) {
        "me" {
            Invoke-IlegnaJiraCli -Arguments @("me")
        }
        "mine" {
            [string[]]$jiraArgs = @("issue", "list", "--jql", "(assignee = currentUser() OR cf[10116] = currentUser() OR text ~ currentUser()) AND statusCategory != Done")
            if ($InputArgs) {
                $jiraArgs += @($InputArgs)
            }
            Invoke-IlegnaJiraCli -Arguments $jiraArgs
        }
        "start" {
            $issue = $parsed.Positionals | Select-Object -First 1
            if ([string]::IsNullOrWhiteSpace($issue)) {
                throw "Usage: ilegna jira start <ISSUE-123> [description]"
            }

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
            if (-not $timer) {
                Write-IlegnaLine "No active timer." Yellow; return
            }

            $started = ConvertFrom-IlegnaTimerStartedAt -Value $timer.startedAt
            $elapsed = New-TimeSpan -Start $started -End (Get-Date)
            Write-IlegnaLine ("{0} running for {1:hh\:mm}" -f $timer.issue, $elapsed) Cyan
            if ($timer.description) {
                Write-IlegnaLine $timer.description DarkGray
            }
        }
        "stop" {
            $timer = Get-IlegnaTimer
            if (-not $timer) {
                Write-IlegnaLine "No active timer." Yellow; return
            }

            $started = ConvertFrom-IlegnaTimerStartedAt -Value $timer.startedAt
            $elapsed = New-TimeSpan -Start $started -End (Get-Date)
            $minutes = [Math]::Max(1, [Math]::Ceiling($elapsed.TotalMinutes))
            $issue = $parsed.Positionals | Select-Object -First 1
            if ([string]::IsNullOrWhiteSpace($issue)) {
                $issue = $timer.issue
            }

            $skipLog = Test-IlegnaFlag -Parsed $parsed -Names @("no-log", "skip-log")
            $log = $false
            $duration = Get-IlegnaOption -Parsed $parsed -Names @("time", "duration", "spent")
            if (-not [string]::IsNullOrWhiteSpace($duration)) {
                $duration = ConvertTo-IlegnaJiraDuration -Value $duration
            }

            if (-not $skipLog) {
                if (Test-IlegnaFlag -Parsed $parsed -Names @("log")) {
                    $log = $true
                }
                elseif (Test-InteractiveShell) {
                    $log = Read-IlegnaYesNo -Prompt ("Log {0}m to Jira issue {1}" -f $minutes, $issue) -Default $true
                }
            }

            if ($log) {
                $defaultDuration = ConvertTo-IlegnaJiraDuration -Value "$($minutes)m"
                if ([string]::IsNullOrWhiteSpace($duration)) {
                    $duration = if (Test-InteractiveShell) {
                        Read-IlegnaJiraDuration -Prompt "Jira time spent" -Default $defaultDuration
                    }
                    else {
                        $defaultDuration
                    }
                }

                $comment = if ($timer.description) {
                    $timer.description
                }
                else {
                    "Automated worklog"
                }
                Add-IlegnaJiraWorklog -Issue $issue -Duration $duration -Comment $comment
            }

            Remove-Item -Path (Get-IlegnaTimerPath) -Force
            $stoppedDuration = if ($log) { $duration } else { "$($minutes)m" }
            Write-IlegnaLine ("Timer stopped for {0}: {1}" -f $issue, $stoppedDuration) Green
        }
        "worklog" {
            $issue = $parsed.Positionals | Select-Object -First 1
            $durationInput = $parsed.Positionals | Select-Object -Skip 1 -First 1
            if ([string]::IsNullOrWhiteSpace($issue) -or [string]::IsNullOrWhiteSpace($durationInput)) {
                throw "Usage: ilegna jira worklog <ISSUE-123> <time> [comment]"
            }

            $duration = ConvertTo-IlegnaJiraDuration -Value $durationInput
            $comment = Get-IlegnaOption -Parsed $parsed -Names @("comment", "message")
            if ([string]::IsNullOrWhiteSpace($comment)) {
                $comment = @($parsed.Positionals | Select-Object -Skip 2) -join " "
            }
            if ([string]::IsNullOrWhiteSpace($comment)) {
                $comment = "Manual worklog"
            }

            Add-IlegnaJiraWorklog -Issue $issue -Duration $duration -Comment $comment
            Write-IlegnaLine ("Worklog added for {0}: {1}" -f $issue, $duration) Green
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
        @{ Name = "rtk"; Command = "rtk" },
        @{ Name = "opencode"; Command = "opencode" }
    )

    foreach ($check in $checks) {
        if ($check.Name -eq "jira") {
            try {
                $null = Resolve-IlegnaJiraCli
                Write-IlegnaLine ("ok   {0}" -f $check.Name) Green
            }
            catch {
                Write-IlegnaLine ("miss {0}" -f $check.Name) Yellow
            }
            continue
        }

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

    if ([string]::IsNullOrWhiteSpace($Subcommand)) {
        $Subcommand = "backup"
    }

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
            if ([string]::IsNullOrWhiteSpace($version)) {
                $version = $positionalVersion
            }
            & $scriptPath -Action restore -Version $version -Items ($items -split ",") -Force:$force
        }
        default {
            throw "Unknown config command: $Subcommand"
        }
    }
}

try {
    if ($Interactive) {
        $CliArgs = @("-i") + @($CliArgs)
    }

    if ([string]::IsNullOrWhiteSpace($Resource)) {
        Show-IlegnaHelp
        return
    }

    if (Test-IlegnaHelpRequest -Values @($Resource)) {
        Show-IlegnaHelp -Resource $Command
        return
    }

    if ((Test-IlegnaHelpRequest -Values @($Command)) -or (Test-IlegnaHelpRequest -Values $CliArgs)) {
        Show-IlegnaHelp -Resource $Resource
        return
    }

    switch (ConvertTo-IlegnaResourceName -Resource $Resource) {
        "wt" {
            Invoke-IlegnaWorktree -Subcommand $Command -InputArgs $CliArgs; break
        }
        "git-bare" {
            Invoke-IlegnaGitBare -Subcommand $Command -InputArgs $CliArgs; break
        }
        "pr" {
            Invoke-IlegnaPullRequest -Subcommand $Command -InputArgs $CliArgs; break
        }
        "pipeline" {
            Invoke-IlegnaPipeline -Subcommand $Command -InputArgs $CliArgs; break
        }
        "jira" {
            Invoke-IlegnaJira -Subcommand $Command -InputArgs $CliArgs; break
        }
        "config" {
            Invoke-IlegnaConfig -Subcommand $Command -InputArgs $CliArgs; break
        }
        "doctor" {
            Invoke-IlegnaDoctor; break
        }
        default {
            throw "Unknown resource: $Resource"
        }
    }
}
catch {
    throw $_.Exception.Message
}
