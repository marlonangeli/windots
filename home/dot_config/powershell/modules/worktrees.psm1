# ============================================
# Git Worktree Management (AI-Friendly)
# PowerShell approved verbs
# ============================================

function Test-GitWorktreeRepository {
    [CmdletBinding()]
    param()
    $null -ne (git rev-parse --is-inside-work-tree 2>$null)
}

function Test-ValidBranchName {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$BranchName)
    git check-ref-format --branch $BranchName *> $null
    return $LASTEXITCODE -eq 0
}

function Get-Worktree {
    <#
    .SYNOPSIS
        Lists all git worktrees in the current repository.

    .DESCRIPTION
        Displays all worktrees associated with the current git repository,
        including their paths and associated branches.

    .EXAMPLE
        Get-Worktree
        Lists all worktrees

    .LINK
        https://git-scm.com/docs/git-worktree
    #>
    [CmdletBinding()]
    param()

    if (-not (Test-GitWorktreeRepository)) {
        Write-Error "Not in a git repository"
        return
    }

    git worktree list
}

function New-Worktree {
    <#
    .SYNOPSIS
        Creates a new git worktree for parallel development.

    .DESCRIPTION
        Creates a new worktree in .worktree/<BranchName> with a new branch.
        Optionally prompts for inputs if parameters are not provided.

    .PARAMETER BranchName
        Name of the new branch to create

    .PARAMETER BaseBranch
        Base branch to create from (default: main)

    .PARAMETER Interactive
        Prompts for all parameters interactively

    .EXAMPLE
        New-Worktree -BranchName "feature-auth"
        Creates worktree with branch feature-auth from main

    .EXAMPLE
        New-Worktree -BranchName "fix-bug" -BaseBranch "develop"
        Creates worktree from develop branch

    .EXAMPLE
        New-Worktree -Interactive
        Prompts for branch name and base branch

    .LINK
        https://git-scm.com/docs/git-worktree
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$BranchName,

        [Parameter(Mandatory=$false)]
        [string]$BaseBranch = "main",

        [Parameter(Mandatory=$false)]
        [string]$BasePath = ".worktree",

        [Parameter(Mandatory=$false)]
        [switch]$Interactive
    )

    if (-not (Test-GitWorktreeRepository)) {
        Write-Error "Not in a git repository"
        return
    }

    # Interactive mode
    if ($Interactive -or -not $BranchName) {
        Write-Host "`n🌿 Create New Worktree" -ForegroundColor Cyan
        Write-Host "=" * 40 -ForegroundColor Cyan

        if (-not $BranchName) {
            $BranchName = Read-Host "`nBranch name"
            if (-not $BranchName) {
                Write-Error "Branch name is required"
                return
            }
        }

        if ($Interactive) {
            $bases = @("main", "develop", "master")
            Write-Host "`nAvailable base branches:" -ForegroundColor Yellow
            for ($i = 0; $i -lt $bases.Count; $i++) {
                Write-Host "  $($i+1). $($bases[$i])" -ForegroundColor Yellow
            }
            Write-Host "  4. Other..." -ForegroundColor Yellow

            $choice = Read-Host "`nSelect base branch (1-4) [default: 1]"
            if (-not $choice) { $choice = "1" }

            if ($choice -eq "4") {
                $BaseBranch = Read-Host "Enter base branch name"
            } elseif ($choice -match '^\d+$' -and [int]$choice -le $bases.Count) {
                $BaseBranch = $bases[[int]$choice - 1]
            }
        }
    }

    if (-not (Test-ValidBranchName -BranchName $BranchName)) {
        Write-Error "Invalid branch name: $BranchName"
        return
    }

    if (-not (Test-Path $BasePath)) {
        New-Item -ItemType Directory -Path $BasePath -Force | Out-Null
    }

    $worktreePath = Join-Path $BasePath $BranchName

    # Validate
    if (Test-Path $worktreePath) {
        Write-Error "Worktree already exists at: $worktreePath"
        return
    }

    Write-Host "`n🌿 Creating worktree: $BranchName" -ForegroundColor Cyan
    Write-Host "📂 Path: $worktreePath" -ForegroundColor Yellow
    Write-Host "🌱 Base: $BaseBranch" -ForegroundColor Yellow

    try {
        git worktree add $worktreePath -b $BranchName $BaseBranch 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n✅ Worktree created successfully!" -ForegroundColor Green

            $response = Read-Host "`nNavigate to worktree? (y/n)"
            if ($response -eq 'y') {
                Set-Location $worktreePath
            }
        } else {
            Write-Error "Failed to create worktree. Check if branch already exists."
        }
    }
    catch {
        Write-Error "Error creating worktree: $_"
    }
}

function Remove-Worktree {
    <#
    .SYNOPSIS
        Removes a git worktree with validation.

    .DESCRIPTION
        Safely removes a worktree after checking for uncommitted changes.
        Optionally prompts to delete the associated branch.

    .PARAMETER BranchName
        Name of the worktree branch to remove

    .PARAMETER Force
        Force removal even with uncommitted changes

    .EXAMPLE
        Remove-Worktree -BranchName "feature-auth"
        Removes the worktree with validation

    .EXAMPLE
        Remove-Worktree -BranchName "feature-auth" -Force
        Forces removal without validation
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory=$false)]
        [string]$BranchName,

        [Parameter(Mandatory=$false)]
        [switch]$Force
    )

    if (-not (Test-GitWorktreeRepository)) {
        Write-Error "Not in a git repository"
        return
    }

    # Interactive mode
    if (-not $BranchName) {
        $worktrees = git worktree list --porcelain | Select-String "^worktree" | ForEach-Object {
            ($_ -replace "^worktree ", "") -replace '.*\\', ''
        }

        if ($worktrees.Count -eq 0) {
            Write-Host "No worktrees found" -ForegroundColor Yellow
            return
        }

        Write-Host "`n🗑️  Remove Worktree" -ForegroundColor Cyan
        Write-Host "=" * 40 -ForegroundColor Cyan
        Write-Host "`nAvailable worktrees:" -ForegroundColor Yellow

        for ($i = 0; $i -lt $worktrees.Count; $i++) {
            Write-Host "  $($i+1). $($worktrees[$i])" -ForegroundColor Yellow
        }

        $choice = Read-Host "`nSelect worktree to remove (1-$($worktrees.Count))"
        if ($choice -match '^\d+$' -and [int]$choice -le $worktrees.Count) {
            $BranchName = $worktrees[[int]$choice - 1]
        } else {
            Write-Error "Invalid selection"
            return
        }
    }

    $worktreePath = ".worktree\$BranchName"

    if (-not (Test-Path $worktreePath)) {
        Write-Error "Worktree not found: $worktreePath"
        return
    }

    # Check for uncommitted changes
    Push-Location $worktreePath -ErrorAction SilentlyContinue
    if ($?) {
        $status = git status --porcelain
        Pop-Location

        if ($status -and -not $Force) {
            Write-Warning "Uncommitted changes found in worktree!"
            Write-Host $status -ForegroundColor Yellow

            $confirm = Read-Host "`nForce remove? (yes/no)"
            if ($confirm -ne 'yes') {
                Write-Host "❌ Aborted" -ForegroundColor Red
                return
            }
            $Force = $true
        }
    }

    try {
        if ($Force) {
            git worktree remove $worktreePath --force
        } else {
            git worktree remove $worktreePath
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Worktree removed: $BranchName" -ForegroundColor Green

            $deleteBranch = Read-Host "`nDelete branch '$BranchName' too? (y/n)"
            if ($deleteBranch -eq 'y') {
                git branch -D $BranchName
                Write-Host "🗑️  Branch deleted" -ForegroundColor Cyan
            }
        }
    }
    catch {
        Write-Error "Error removing worktree: $_"
    }
}

function Open-Worktree {
    <#
    .SYNOPSIS
        Opens a worktree in the specified editor.

    .DESCRIPTION
        Opens the worktree directory in an editor (Zed, VS Code, Rider, or Visual Studio)
        and navigates to that directory.

    .PARAMETER BranchName
        Name of the worktree branch to open

    .PARAMETER Editor
        Editor to use: zed, code, rider, vs (default: zed)

    .EXAMPLE
        Open-Worktree -BranchName "feature-auth"
        Opens feature-auth worktree in Zed

    .EXAMPLE
        Open-Worktree -BranchName "feature-auth" -Editor code
        Opens in VS Code
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$BranchName,

        [Parameter(Mandatory=$false)]
        [ValidateSet("zed", "code", "rider", "vs")]
        [string]$Editor = "zed"
    )

    if (-not (Test-GitWorktreeRepository)) {
        Write-Error "Not in a git repository"
        return
    }

    # Interactive mode
    if (-not $BranchName) {
        $worktrees = git worktree list --porcelain | Select-String "^worktree" | ForEach-Object {
            ($_ -replace "^worktree ", "") -replace '.*\\', ''
        }

        if ($worktrees.Count -eq 0) {
            Write-Host "No worktrees found" -ForegroundColor Yellow
            return
        }

        Write-Host "`n📝 Open Worktree" -ForegroundColor Cyan
        Write-Host "=" * 40 -ForegroundColor Cyan
        Write-Host "`nAvailable worktrees:" -ForegroundColor Yellow

        for ($i = 0; $i -lt $worktrees.Count; $i++) {
            Write-Host "  $($i+1). $($worktrees[$i])" -ForegroundColor Yellow
        }

        $choice = Read-Host "`nSelect worktree (1-$($worktrees.Count))"
        if ($choice -match '^\d+$' -and [int]$choice -le $worktrees.Count) {
            $BranchName = $worktrees[[int]$choice - 1]
        } else {
            Write-Error "Invalid selection"
            return
        }
    }

    $worktreePath = ".worktree\$BranchName"

    if (-not (Test-Path $worktreePath)) {
        Write-Error "Worktree not found: $worktreePath"
        return
    }

    Write-Host "📝 Opening $worktreePath in $Editor..." -ForegroundColor Cyan

    try {
        switch ($Editor.ToLower()) {
            "zed" { zed $worktreePath }
            "code" { code $worktreePath }
            "rider" { rider64.exe $worktreePath }
            "vs" { devenv $worktreePath }
        }

        Set-Location $worktreePath
    }
    catch {
        Write-Error "Error opening worktree: $_"
    }
}

function Get-WorktreeStatus {
    <#
    .SYNOPSIS
        Shows detailed status of all worktrees.

    .DESCRIPTION
        Displays comprehensive information about all worktrees including
        paths, branches, and commit information.

    .EXAMPLE
        Get-WorktreeStatus
        Shows status of all worktrees
    #>
    [CmdletBinding()]
    param()

    if (-not (Test-GitWorktreeRepository)) {
        Write-Error "Not in a git repository"
        return
    }

    Write-Host "`n📊 Worktree Status" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan

    $worktrees = git worktree list --porcelain
    $currentWorktree = $null

    foreach ($line in $worktrees) {
        if ($line -match '^worktree (.+)$') {
            if ($currentWorktree) {
                Write-Host ""
            }
            $currentWorktree = @{ Path = $Matches[1] }
            Write-Host "`n📁 $($Matches[1])" -ForegroundColor Yellow
        }
        elseif ($line -match '^branch (.+)$') {
            $currentWorktree.Branch = $Matches[1]
            Write-Host "   🌿 Branch: $($Matches[1])" -ForegroundColor Green
        }
    }

    Write-Host "`n" -NoNewline
}

function Clear-Worktree {
    <#
    .SYNOPSIS
        Prunes stale worktree administrative data.

    .DESCRIPTION
        Removes worktree information for worktrees that no longer exist
        in the filesystem.

    .EXAMPLE
        Clear-Worktree
        Cleans up orphaned worktrees
    #>
    [CmdletBinding()]
    param()

    if (-not (Test-GitWorktreeRepository)) {
        Write-Error "Not in a git repository"
        return
    }

    Write-Host "🧹 Pruning stale worktrees..." -ForegroundColor Cyan
    git worktree prune -v
    Write-Host "✅ Done" -ForegroundColor Green
}

function Switch-Worktree {
    <#
    .SYNOPSIS
        Quickly switches between worktrees.

    .DESCRIPTION
        Interactive menu to switch between available worktrees.
        Navigates to the selected worktree directory.

    .PARAMETER BranchName
        Name of the worktree to switch to (optional, prompts if not provided)

    .EXAMPLE
        Switch-Worktree
        Shows interactive menu

    .EXAMPLE
        Switch-Worktree -BranchName "feature-auth"
        Switches directly to feature-auth worktree
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$BranchName
    )

    if (-not (Test-GitWorktreeRepository)) {
        Write-Error "Not in a git repository"
        return
    }

    if (-not $BranchName) {
        $worktrees = git worktree list --porcelain | Select-String "^worktree" | ForEach-Object {
            $_ -replace "^worktree ", ""
        }

        Write-Host "`n📂 Switch Worktree" -ForegroundColor Cyan
        Write-Host "=" * 40 -ForegroundColor Cyan
        Write-Host "`nAvailable worktrees:" -ForegroundColor Yellow

        $i = 1
        $paths = @()
        foreach ($wt in $worktrees) {
            Write-Host "  $i. $wt" -ForegroundColor Yellow
            $paths += $wt
            $i++
        }

        $choice = Read-Host "`nSelect worktree (1-$($worktrees.Count))"
        if ($choice -match '^\d+$' -and [int]$choice -le $worktrees.Count) {
            Set-Location $paths[[int]$choice - 1]
        } else {
            Write-Error "Invalid selection"
        }
    } else {
        $worktreePath = ".worktree\$BranchName"
        if (Test-Path $worktreePath) {
            Set-Location $worktreePath
        } else {
            Write-Error "Worktree not found: $BranchName"
        }
    }
}

function New-WorktreeAI {
    <#
    .SYNOPSIS
        Creates a worktree with AI assistant context.

    .DESCRIPTION
        Creates a new worktree and generates a .ai-context.md file with
        structured context for AI coding assistants (Copilot, Cursor, Windsurf).

    .PARAMETER FeatureName
        Name of the feature

    .PARAMETER Description
        Detailed description for AI context

    .EXAMPLE
        New-WorktreeAI -FeatureName "oauth-integration" -Description "Add OAuth2 with Google/GitHub"
        Creates worktree with AI context file

    .EXAMPLE
        New-WorktreeAI
        Interactive mode with prompts
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$FeatureName,

        [Parameter(Mandatory=$false)]
        [string]$Description
    )

    if (-not (Test-GitWorktreeRepository)) {
        Write-Error "Not in a git repository"
        return
    }

    # Interactive mode
    if (-not $FeatureName) {
        Write-Host "`n🤖 Create AI-Friendly Worktree" -ForegroundColor Cyan
        Write-Host "=" * 40 -ForegroundColor Cyan

        $FeatureName = Read-Host "`nFeature name"
        if (-not $FeatureName) {
            Write-Error "Feature name is required"
            return
        }

        $Description = Read-Host "Description (optional)"
    }

    $branchName = $FeatureName.ToLower() -replace '[^a-z0-9-]', '-'

    Write-Host "`n🤖 Creating AI-friendly worktree..." -ForegroundColor Cyan
    New-Worktree -BranchName $branchName

    if ($LASTEXITCODE -eq 0) {
        $worktreePath = ".worktree\$branchName"
        $aiDir = Join-Path $worktreePath ".ai"
        if (-not (Test-Path $aiDir)) {
            New-Item -ItemType Directory -Path $aiDir -Force | Out-Null
        }
        $readmePath = Join-Path $aiDir "context.md"
        $contextContent = @"
# Feature: $FeatureName

## Description
$Description

## Worktree Info
- Branch: ``$branchName``
- Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
- Base Branch: main

## Development Notes
<!-- Add context, requirements, and notes for AI assistants here -->

## Tasks
- [ ] Implement feature / Fix bug
- [ ] Tests
- [ ] Documentation
- [ ] Code review

## AI Assistant Instructions
- Use this worktree for isolated development
- All changes should be committed to branch: ``$branchName``
- Run tests before pushing
- Follow project coding standards
"@

        $localExclude = Join-Path (git rev-parse --git-common-dir) "info\exclude"
        if (Test-Path $localExclude) {
            $excludeContent = Get-Content $localExclude -ErrorAction SilentlyContinue
            if ($excludeContent -notcontains ".ai/" -and $excludeContent -notcontains ".worktree/**/.ai/") {
                Add-Content -Path $localExclude -Value "`n.ai/`n.worktree/**/.ai/"
            }
        }

        Set-Content -Path $readmePath -Value $contextContent
        Write-Host "📝 AI context created: .ai/context.md" -ForegroundColor Green
        Write-Host "🚀 Ready for AI coding assistant (Copilot/Cursor/Windsurf)" -ForegroundColor Magenta
    }
}

# Aliases (mantém compatibilidade)
Set-Alias gwt Get-Worktree -Force -ErrorAction SilentlyContinue
Set-Alias gwtl Get-Worktree -Force -ErrorAction SilentlyContinue
Set-Alias gwtn New-Worktree -Force -ErrorAction SilentlyContinue
Set-Alias gwtr Remove-Worktree -Force -ErrorAction SilentlyContinue
Set-Alias gwto Open-Worktree -Force -ErrorAction SilentlyContinue
Set-Alias gwts Get-WorktreeStatus -Force -ErrorAction SilentlyContinue
Set-Alias gwtw Switch-Worktree -Force -ErrorAction SilentlyContinue
Set-Alias gwt-ai New-WorktreeAI -Force -ErrorAction SilentlyContinue

# Export functions
Export-ModuleMember -Function Get-Worktree, New-Worktree, Remove-Worktree, Open-Worktree, Get-WorktreeStatus, Clear-Worktree, Switch-Worktree, New-WorktreeAI -Alias *
