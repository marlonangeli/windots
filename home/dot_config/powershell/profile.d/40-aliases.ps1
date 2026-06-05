Set-Alias g git -Force -ErrorAction SilentlyContinue
Set-Alias d docker -Force -ErrorAction SilentlyContinue
Set-Alias dc docker-compose -Force -ErrorAction SilentlyContinue
Set-Alias dn dotnet -Force -ErrorAction SilentlyContinue
Set-Alias mi mise -Force -ErrorAction SilentlyContinue

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

function ll {
    if (Get-Command eza -ErrorAction SilentlyContinue) { eza --icons --group-directories-first @args; return }
    Get-ChildItem @args
}

function la {
    if (Get-Command eza -ErrorAction SilentlyContinue) { eza --all --icons --group-directories-first @args; return }
    Get-ChildItem -Force @args
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
