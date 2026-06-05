Set-Alias g git -Force -ErrorAction SilentlyContinue
Set-Alias d docker -Force -ErrorAction SilentlyContinue
Set-Alias dc docker-compose -Force -ErrorAction SilentlyContinue
Set-Alias dn dotnet -Force -ErrorAction SilentlyContinue
Set-Alias mi mise -Force -ErrorAction SilentlyContinue
Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
Remove-Item Alias:dir -Force -ErrorAction SilentlyContinue

function gs { git status -sb @args }
function ga { git add @args }
function gaa { git add . @args }
function gc { git commit @args }
function gcm { git commit -m ($args -join " ") }
function gp { git push @args }
function gpl { git pull @args }
function gsw { git switch @args }
function gcb { git switch -c @args }
function gd { git diff @args }
function gl { git log --oneline --graph --decorate -n 12 @args }
function gst { git stash @args }
function gstp { git stash pop @args }

function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }
function ~ { Set-Location $HOME }
function docs { Set-Location (Join-Path $HOME "Documents") }
function dl { Set-Location (Join-Path $HOME "Downloads") }

function ls {
    if (Get-Command eza -ErrorAction SilentlyContinue) { eza --icons --group-directories-first @args; return }
    Get-ChildItem @args
}

function dir { ls @args }
function ll { ls @args }

function la {
    if (Get-Command eza -ErrorAction SilentlyContinue) { eza --all --icons --group-directories-first @args; return }
    Get-ChildItem -Force @args
}

$global:__WindotsZoxideLoaded = $false
function Enable-Zoxide {
    if ($global:__WindotsZoxideLoaded) { return $true }
    if (-not (Get-Command zoxide -ErrorAction SilentlyContinue)) { return $false }

    if (Invoke-ShellInitScript -Command "zoxide" -Arguments @("init", "powershell")) {
        $global:__WindotsZoxideLoaded = $true
        return $true
    }

    return $false
}

function z {
    if ((Enable-Zoxide) -and (Get-Command __zoxide_z -ErrorAction SilentlyContinue)) { __zoxide_z @args; return }
    if ($args.Count -gt 0) { Set-Location @args; return }
    Set-Location $HOME
}

function zi {
    if ((Enable-Zoxide) -and (Get-Command __zoxide_zi -ErrorAction SilentlyContinue)) { __zoxide_zi @args; return }
    Write-Warning "zoxide interactive mode is not available."
}

function catp {
    if (Get-Command bat -ErrorAction SilentlyContinue) { bat @args; return }
    Get-Content @args
}

function lg { lazygit @args }
function yz { yazi @args }
function zj { zellij @args }
function c { code . @args }
function zedp { zed . @args }

function arch { wsl -d Arch @args }
function ubuntu { wsl -d Ubuntu @args }
