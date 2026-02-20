# ============================================
# PR Workflow Management (Azure DevOps)
# Flow: main → feat/fix → PR to develop → PR to main
# PowerShell approved verbs and interactive
# ============================================

function Test-GitRepository {
    [CmdletBinding()]
    param()
    $null -ne (git rev-parse --is-inside-work-tree 2>$null)
}

function Test-AzureDevOpsRepository {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    $url = git remote get-url origin 2>$null
    if (-not $url) { return $false }
    return $url -match "dev\.azure\.com|\.visualstudio\.com"
}

function Test-JiraIssueFormat {
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][string]$IssueKey)
    return $IssueKey -match '^[A-Z][A-Z0-9]+-\d+$'
}

function Test-JiraIssueExists {
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][string]$IssueKey)

    if (-not (Get-Command jira -ErrorAction SilentlyContinue)) { return $false }
    jira issue view $IssueKey --plain *> $null
    return $LASTEXITCODE -eq 0
}

function New-Feature {
    <#
    .SYNOPSIS
        Creates a new feature or fix branch from main.

    .DESCRIPTION
        Creates a new branch with proper naming convention (feat/fix/hotfix/etc)
        from the main branch. Optionally creates as a git worktree and starts
        a work timer for the associated Jira issue.

    .PARAMETER Name
        Name of the feature (will be sanitized)

    .PARAMETER Type
        Type of branch: feat, fix, hotfix, refactor, docs, test, chore

    .PARAMETER IssueKey
        Jira issue key (e.g., AL-1234)

    .PARAMETER Worktree
        Create as a git worktree instead of regular branch

    .PARAMETER Interactive
        Prompt for all parameters interactively

    .EXAMPLE
        New-Feature -Name "authentication" -Type "feat" -IssueKey "AL-1234"
        Creates feat/AL-1234-authentication branch

    .EXAMPLE
        New-Feature -Interactive
        Interactive mode with prompts

    .EXAMPLE
        New-Feature -Name "bug-fix" -Type "fix" -Worktree
        Creates fix/bug-fix as a worktree

    .LINK
        New-PR
        Complete-Feature
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Name,

        [Parameter(Mandatory=$false)]
        [ValidateSet("feat", "fix", "hotfix", "refactor", "docs", "test", "chore")]
        [string]$Type = "feat",

        [Parameter(Mandatory=$false)]
        [string]$IssueKey,

        [Parameter(Mandatory=$false)]
        [switch]$Worktree,

        [Parameter(Mandatory=$false)]
        [string]$BaseBranch = "main",

        [Parameter(Mandatory=$false)]
        [switch]$Interactive
    )

    if (-not (Test-GitRepository)) {
        Write-Error "Not in a git repository"
        return
    }
    if (-not (Test-AzureDevOpsRepository)) {
        Write-Warning "Origin remote does not look like Azure DevOps. Continuing anyway."
    }

    # Interactive mode
    if ($Interactive -or -not $Name) {
        Write-Host "`n🌿 Create New Feature Branch" -ForegroundColor Cyan
        Write-Host "=" * 40 -ForegroundColor Cyan

        if (-not $Name) {
            $Name = Read-Host "`nFeature name (e.g., 'user-authentication')"
            if (-not $Name) {
                Write-Error "Feature name is required"
                return
            }
        }

        if ($Interactive) {
            $types = @("feat", "fix", "hotfix", "refactor", "docs", "test", "chore")
            Write-Host "`nBranch types:" -ForegroundColor Yellow
            for ($i = 0; $i -lt $types.Count; $i++) {
                Write-Host "  $($i+1). $($types[$i])" -ForegroundColor Yellow
            }

            $choice = Read-Host "`nSelect type (1-$($types.Count)) [default: 1]"
            if (-not $choice) { $choice = "1" }
            if ($choice -match '^\d+$' -and [int]$choice -le $types.Count) {
                $Type = $types[[int]$choice - 1]
            }

            $IssueKey = Read-Host "Jira issue key (e.g., AL-1234, press Enter to skip)"
            if ($IssueKey -and -not (Test-JiraIssueFormat -IssueKey $IssueKey)) {
                Write-Warning "Invalid issue key format (expected ABC-123)"
            } elseif ($IssueKey -and (Get-Command jira -ErrorAction SilentlyContinue) -and -not (Test-JiraIssueExists -IssueKey $IssueKey)) {
                Write-Warning "Issue not found in Jira: $IssueKey"
            }

            $useWorktree = Read-Host "Create as worktree? (y/n) [default: n]"
            $Worktree = ($useWorktree -eq 'y')
        }
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-Error "Feature name is required"
        return
    }

    # Sanitize name
    $sanitized = $Name.ToLower() -replace '[^a-z0-9-]', '-'
    if ([string]::IsNullOrWhiteSpace($sanitized)) {
        Write-Error "Feature name produced an invalid branch segment."
        return
    }
    $branchName = if ($IssueKey) { "$Type/$IssueKey-$sanitized" } else { "$Type/$sanitized" }
    git check-ref-format --branch $branchName *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Invalid branch name generated: $branchName"
        return
    }

    Write-Host "`n🌿 Creating branch: $branchName from $BaseBranch" -ForegroundColor Cyan

    # Atualizar base branch primeiro
    $currentBranch = git branch --show-current
    git fetch origin $BaseBranch
    git checkout $BaseBranch
    git pull origin $BaseBranch

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to update base branch: $BaseBranch"
        git checkout $currentBranch
        return
    }

    if ($Worktree) {
        # Criar como worktree
        if (Get-Command New-Worktree -ErrorAction SilentlyContinue) {
            New-Worktree -BranchName $branchName -BaseBranch $BaseBranch
        } else {
            Write-Error "Worktree module not loaded. Use -Worktree:$false or load worktrees module."
            return
        }
    } else {
        # Criar branch normal
        git checkout -b $branchName $BaseBranch

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Branch created: $branchName" -ForegroundColor Green

            # Iniciar timer se tiver issue key
            if ($IssueKey -and (Get-Command Start-Work -ErrorAction SilentlyContinue)) {
                $startTimer = Read-Host "`nStart work timer? (y/n) [default: y]"
                if (-not $startTimer -or $startTimer -eq 'y') {
                    Start-Work -IssueKey $IssueKey -Description "Working on $branchName" -NoPrompt
                }
            }
        } else {
            Write-Error "Failed to create branch"
        }
    }
}

function Test-MergeConflict {
    <#
    .SYNOPSIS
        Checks for merge conflicts with develop branch.

    .DESCRIPTION
        Performs a dry-run merge test to detect potential conflicts
        between the current branch and develop branch before creating a PR.

    .EXAMPLE
        Test-DevConflict
        Checks current branch for conflicts with develop

    .OUTPUTS
        Boolean - $true if no conflicts, $false if conflicts detected

    .LINK
        New-MergeBranch
        New-PR
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$false)]
        [string]$CompareBranch = "develop"
    )

    $currentBranch = git branch --show-current

    if (-not (Test-GitRepository)) {
        Write-Error "Not in a git repository"
        return $false
    }

    Write-Host "`n🔍 Checking conflicts with $CompareBranch..." -ForegroundColor Cyan

    # Fetch compare branch
    git fetch origin $CompareBranch

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to fetch branch: $CompareBranch"
        return $false
    }

    # Simular merge (dry-run)
    $mergeTest = git merge-tree $(git merge-base HEAD origin/$CompareBranch) HEAD origin/$CompareBranch 2>&1

    if ($mergeTest -match '<<<<<<< ') {
        Write-Host "⚠️  CONFLICTS DETECTED with $CompareBranch!" -ForegroundColor Red
        Write-Host "`n📋 Next steps:" -ForegroundColor Yellow
        Write-Host "  1. Create merge branch: New-MergeBranch" -ForegroundColor Yellow
        Write-Host "  2. Resolve conflicts" -ForegroundColor Yellow
        Write-Host "  3. Create PR with merge branch" -ForegroundColor Yellow
        return $false
    } else {
        Write-Host "✅ No conflicts with develop" -ForegroundColor Green
        return $true
    }
}

function Test-DevConflict {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$false)]
        [string]$CompareBranch = "develop"
    )

    Test-MergeConflict -CompareBranch $CompareBranch
}

function New-MergeBranch {
    <#
    .SYNOPSIS
        Creates a temporary merge branch to resolve conflicts.

    .DESCRIPTION
        Creates a new branch with '-merge-dev' suffix and pulls develop
        to allow conflict resolution before creating a PR.

    .EXAMPLE
        New-MergeBranch
        Creates merge branch from current branch

    .LINK
        Test-DevConflict
        New-PR
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$CompareBranch = "develop"
    )

    $currentBranch = git branch --show-current

    if ($currentBranch -eq "main" -or $currentBranch -eq "develop") {
        Write-Error "Cannot create merge branch from main/develop"
        return
    }

    $mergeSuffix = $CompareBranch -replace '[^a-zA-Z0-9\-]', '-'
    $mergeBranchName = "$currentBranch-merge-$mergeSuffix"

    Write-Host "`n🔀 Creating merge branch: $mergeBranchName" -ForegroundColor Cyan

    git checkout -b $mergeBranchName

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create merge branch"
        return
    }

    Write-Host "📥 Pulling $CompareBranch..." -ForegroundColor Cyan
    git pull origin $CompareBranch

    Write-Host "`n📝 Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Resolve conflicts in your editor" -ForegroundColor Yellow
    Write-Host "  2. Stage changes: ga ." -ForegroundColor Yellow
    Write-Host "  3. Commit: gc 'resolve merge conflicts with $CompareBranch'" -ForegroundColor Yellow
    Write-Host "  4. Push: gp -u origin $mergeBranchName" -ForegroundColor Yellow
    Write-Host "  5. Create PR: New-PR -Target develop" -ForegroundColor Yellow
}

function New-PR {
    <#
    .SYNOPSIS
        Creates a Pull Request to develop or main.

    .DESCRIPTION
        Creates a PR using Azure CLI with proper formatting, templates,
        and issue key integration. Automatically extracts issue key from
        branch name if not provided.

    .PARAMETER Target
        Target branch: develop or main

    .PARAMETER Title
        PR title (auto-generated if not provided)

    .PARAMETER IssueKey
        Jira issue key (extracted from branch name if available)

    .PARAMETER Draft
        Create as draft PR

    .PARAMETER Interactive
        Prompt for all parameters

    .EXAMPLE
        New-PR -Target develop
        Creates PR to develop with auto-generated title

    .EXAMPLE
        New-PR -Target main -IssueKey "AL-1234" -Title "Add authentication"
        Creates PR with specific title

    .EXAMPLE
        New-PR -Interactive
        Interactive mode with prompts

    .LINK
        New-Feature
        Complete-Feature
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet("develop", "main")]
        [string]$Target,

        [Parameter(Mandatory=$false)]
        [string]$Title,

        [Parameter(Mandatory=$false)]
        [string]$IssueKey,

        [Parameter(Mandatory=$false)]
        [switch]$Draft,

        [Parameter(Mandatory=$false)]
        [string]$TemplatePath,

        [Parameter(Mandatory=$false)]
        [string]$Description,

        [Parameter(Mandatory=$false)]
        [switch]$Interactive
    )

    if (-not (Test-GitRepository)) {
        Write-Error "Not in a git repository"
        return
    }

    # Check Azure CLI
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Error "Azure CLI not found. Install: winget install Microsoft.AzureCLI"
        return
    }

    $currentBranch = git branch --show-current

    # Interactive mode
    if ($Interactive -or -not $Target) {
        Write-Host "`n📤 Create Pull Request" -ForegroundColor Cyan
        Write-Host "=" * 40 -ForegroundColor Cyan
        Write-Host "`nCurrent branch: $currentBranch" -ForegroundColor Yellow

        if (-not $Target) {
            Write-Host "`nTarget branch:" -ForegroundColor Yellow
            Write-Host "  1. develop" -ForegroundColor Yellow
            Write-Host "  2. main" -ForegroundColor Yellow

            $choice = Read-Host "`nSelect target (1-2) [default: 1]"
            if (-not $choice) { $choice = "1" }
            $Target = if ($choice -eq "2") { "main" } else { "develop" }
        }

        # Extract issue key from branch
        if (-not $IssueKey -and $currentBranch -match '(AL-\d+)') {
            $IssueKey = $Matches[1]
            Write-Host "`n📋 Detected issue: $IssueKey" -ForegroundColor Cyan
        }

        if ($Interactive -and -not $IssueKey) {
            $IssueKey = Read-Host "Jira issue key (press Enter to skip)"
        }

        if ($Interactive -and -not $Title) {
            $Title = Read-Host "PR title (press Enter for auto-generated)"
        }

        if ($Interactive) {
            $draftChoice = Read-Host "Create as draft? (y/n) [default: n]"
            $Draft = ($draftChoice -eq 'y')
        }
    }

    # Extrair issue key do branch se não fornecido
    if (-not $IssueKey -and $currentBranch -match '(AL-\d+)') {
        $IssueKey = $Matches[1]
    }

    # Gerar título se não fornecido
    if (-not $Title) {
        $branchPart = $currentBranch -replace '^(feat|fix|hotfix|refactor)/', '' -replace '-', ' '
        if ($IssueKey) {
            $Title = "$IssueKey - $branchPart"
        } else {
            $Title = $branchPart
        }
    } elseif ($IssueKey -and $Title -notmatch "^$IssueKey") {
        $Title = "$IssueKey - $Title"
    }

    Write-Host "`n📤 Creating PR: $currentBranch → $Target" -ForegroundColor Cyan
    Write-Host "📋 Title: $Title" -ForegroundColor Yellow

    if (-not $Description) {
        if (-not $TemplatePath) {
            $branchType = if ($currentBranch -match '^([^/]+)/') { $Matches[1] } else { "" }
            $branchTemplate = if ($branchType) { ".\.azuredevops\pull_request_template.$branchType.md" } else { $null }
            $templatePaths = @(
                $branchTemplate,
                ".\.azuredevops\pull_request_template.md",
                ".\.github\pull_request_template.md",
                "$env:USERPROFILE\.azuredevops\pull_request_template.md"
            ) | Where-Object { $_ }
            $TemplatePath = $templatePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
        }

        $Description = if ($TemplatePath) {
            Get-Content $TemplatePath -Raw
            Write-Host "📝 Using template: $TemplatePath" -ForegroundColor Cyan
        } else {
        @"
## Changes


## Testing


## Related Issues
$(if ($IssueKey) { "- $IssueKey" } else { "" })
"@
        }
    }

    try {
        Write-Host "`n🚀 Creating PR..." -ForegroundColor Cyan
        $prArgs = @(
            "repos", "pr", "create",
            "--source-branch", $currentBranch,
            "--target-branch", $Target,
            "--title", $Title,
            "--description", $Description
        )
        if ($Draft) { $prArgs += "--draft" }
        az @prArgs

        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n✅ PR created successfully!" -ForegroundColor Green

            if ($Target -eq "develop") {
                Write-Host "`n📝 Next steps after PR approval:" -ForegroundColor Yellow
                Write-Host "  1. Wait for PR to be approved and completed" -ForegroundColor Yellow
                Write-Host "  2. Create PR to main: New-PR -Target main" -ForegroundColor Yellow
            }
        } else {
            Write-Error "Failed to create PR. Check Azure CLI configuration (az devops configure)"
        }
    }
    catch {
        Write-Error "Error creating PR: $_"
        Write-Host "💡 Ensure you're logged in: az login" -ForegroundColor Yellow
        Write-Host "💡 Configure defaults: az devops configure --defaults organization=<org> project=<project>" -ForegroundColor Yellow
    }
}

function Complete-Feature {
    <#
    .SYNOPSIS
        Completes the full feature workflow.

    .DESCRIPTION
        Executes the complete PR workflow: check conflicts, create PR to develop,
        stop timer, and log time to Jira.

    .PARAMETER IssueKey
        Jira issue key

    .PARAMETER SkipTimer
        Don't stop timer or log to Jira

    .PARAMETER SkipConflictCheck
        Skip conflict detection with develop

    .EXAMPLE
        Complete-Feature -IssueKey "AL-1234"
        Runs full workflow with conflict check

    .EXAMPLE
        Complete-Feature -SkipTimer
        Completes feature without time tracking

    .LINK
        New-Feature
        New-PR
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$IssueKey,

        [Parameter(Mandatory=$false)]
        [switch]$SkipTimer,

        [Parameter(Mandatory=$false)]
        [switch]$SkipConflictCheck
    )

    $currentBranch = git branch --show-current

    Write-Host "`n🎯 Completing feature workflow" -ForegroundColor Magenta
    Write-Host "=" * 50 -ForegroundColor Magenta

    # 1. Verificar conflitos com develop
    if (-not $SkipConflictCheck) {
        Write-Host "`nStep 1: Checking conflicts with develop..." -ForegroundColor Cyan
        $noConflict = Test-MergeConflict -CompareBranch "develop"

        if (-not $noConflict) {
            Write-Host "`n⚠️  Conflicts detected. Create merge branch first:" -ForegroundColor Yellow
            Write-Host "  New-MergeBranch" -ForegroundColor Yellow
            return
        }
    }

    # 2. Criar PR para develop
    Write-Host "`nStep 2: Creating PR to develop..." -ForegroundColor Cyan
    New-PR -Target develop -IssueKey $IssueKey

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create PR"
        return
    }

    # 3. Parar timer e logar tempo
    if (-not $SkipTimer) {
        if ($global:__TimeTracker.Start -and (Get-Command Stop-Work -ErrorAction SilentlyContinue)) {
            Write-Host "`nStep 3: Stopping timer..." -ForegroundColor Cyan
            Stop-Work -IssueKey $IssueKey -Comment "Completed $currentBranch - PR created" -Force
        }
    }

    Write-Host "`n✅ Feature workflow completed!" -ForegroundColor Green
    Write-Host "`n📋 After PR to develop is approved and merged:" -ForegroundColor Yellow
    Write-Host "   git checkout $currentBranch" -ForegroundColor Yellow
    Write-Host "   New-PR -Target main -IssueKey $IssueKey" -ForegroundColor Yellow
}

function Get-MyPRs {
    <#
    .SYNOPSIS
        Lists your active pull requests.

    .DESCRIPTION
        Displays all active PRs created by you using Azure CLI.

    .PARAMETER Status
        PR status filter: active, completed, abandoned, all

    .EXAMPLE
        Get-MyPRs
        Lists all active PRs

    .EXAMPLE
        Get-MyPRs -Status completed
        Lists completed PRs
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet("active", "completed", "abandoned", "all")]
        [string]$Status = "active"
    )

    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Error "Azure CLI not found"
        return
    }

    $userEmail = git config user.email

    Write-Host "`n📋 Your Pull Requests ($Status):`n" -ForegroundColor Cyan

    try {
        az repos pr list --creator $userEmail --status $Status --output table
    }
    catch {
        Write-Error "Failed to fetch PRs. Ensure Azure CLI is configured: az devops configure"
    }
}

# Aliases (mantém compatibilidade)
Set-Alias nf New-Feature -Force -ErrorAction SilentlyContinue
Set-Alias npr New-PR -Force -ErrorAction SilentlyContinue
Set-Alias cf Complete-Feature -Force -ErrorAction SilentlyContinue
Set-Alias prs Get-MyPRs -Force -ErrorAction SilentlyContinue

# Export functions
Export-ModuleMember -Function New-Feature, Test-MergeConflict, Test-DevConflict, New-MergeBranch, New-PR, Complete-Feature, Get-MyPRs -Alias *
