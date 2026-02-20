# ============================================
# Git Aliases
# ============================================

Set-Alias g git -Force -ErrorAction SilentlyContinue

function gs { git status @args }
function ga { git add @args }
function gc { param([Parameter(ValueFromRemainingArguments)]$msg) git commit -m ($msg -join ' ') }
function gp { git push @args }
function gpl { git pull @args }
function gco { git checkout @args }
function gcb { git checkout -b @args }
function gd { git diff @args }
function gl { git log --oneline --graph --decorate -n 10 }
function gll { git log --oneline --graph --decorate @args }
function gst { git stash @args }
function gstp { git stash pop @args }
function gaa { git add . @args }
function gcam { param([Parameter(ValueFromRemainingArguments)]$msg) git commit -am ($msg -join ' ') }
function gf { git fetch @args }
function gb { git branch @args }
function gr { git reset @args }
function gwt { git worktree @args }
function gsw { git switch @args }
function grh { git reset --hard @args }

# ============================================
# Docker Aliases
# ============================================

Set-Alias d docker -Force -ErrorAction SilentlyContinue
Set-Alias dc docker-compose -Force -ErrorAction SilentlyContinue

function dps { docker ps @args }
function dpsa { docker ps -a @args }
function dimg { docker images @args }
function dstop { docker stop @args }
function drm { docker rm @args }
function drmi { docker rmi @args }
function dprune { docker system prune -af }
function dlogs { docker logs -f @args }
function dexec { docker exec -it @args }
function dsh { param($container) docker exec -it $container sh }
function dbash { param($container) docker exec -it $container bash }

# ============================================
# Dotnet Aliases
# ============================================

Set-Alias dn dotnet -Force -ErrorAction SilentlyContinue

function dnr { dotnet run @args }
function dnb { dotnet build @args }
function dnt { dotnet test @args }
function dnc { dotnet clean @args }
function dnw { dotnet watch run @args }
function dnrs { dotnet restore @args }
function dnp { dotnet publish @args }
function dnef { dotnet ef @args }
function dna { dotnet aspire @args }
function dntool { dotnet tool @args }

# ============================================
# Node/NPM Aliases
# ============================================

function ni { npm install @args }
function nid { npm install --save-dev @args }
function nr { npm run @args }
function ns { npm start @args }
function nt { npm test @args }
function nb { npm run build @args }
function nci { npm ci @args }
function b { bun @args }
function pn { pnpm @args }
function y { yarn @args }
function mi { mise @args }
function nrb { npm run build @args }

# ============================================
# Navigation Aliases
# ============================================

function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }
function ~ { Set-Location ~ }
function docs { Set-Location ~/Documents }
function dl { Set-Location ~/Downloads }

# ============================================
# WSL Aliases
# ============================================

function ubuntu { wsl -d Ubuntu @args }
Set-Alias u ubuntu -Force -ErrorAction SilentlyContinue
function arch { wsl -d Arch @args }

# ============================================
# Azure DevOps + Jira shortcuts
# ============================================

function azd { az devops @args }
function azr { az repos @args }
function azpr { az repos pr @args }
function azpip { az pipelines @args }

function jr { jira @args }
function jme { jira me @args }
function jmy { jira list --assignee '@me' @args }
