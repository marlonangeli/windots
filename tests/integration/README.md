# Integration Tests (Windows)

## Prerequisites
- PowerShell 7+
- winget
- chezmoi

## Scenarios
1. Fresh install with prompts:
   - `irm https://windots.ilegna.dev/install | iex`
   - `& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/marlonangeli/windots/main/install.ps1"))) -AutoApply`
2. Unattended install:
   - `& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/marlonangeli/windots/main/install.ps1"))) -AutoApply -NoPrompt`
3. Branch/ref/local source selection:
   - `pwsh -NoProfile -File ./install.ps1 -Branch feature/install-refactor -AutoApply`
   - `pwsh -NoProfile -File ./install.ps1 -Ref <sha-ou-tag> -AutoApply`
   - `pwsh -NoProfile -File ./install.ps1 -LocalRepoPath C:\\src\\windots -AutoApply`
4. Module subset:
   - `pwsh ./scripts/bootstrap.ps1 -Mode full -Modules core,shell,terminal`
5. Safe update flow:
   - `pwsh ./scripts/windots.ps1 -Command update`
6. Idempotence:
   - run bootstrap/update twice and confirm no unexpected changes.

## Validation
- `pwsh ./scripts/validate.ps1`
- `pwsh ./scripts/validate-modules.ps1`
