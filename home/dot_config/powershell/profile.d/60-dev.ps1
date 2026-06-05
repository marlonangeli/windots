function nr { npm run @args }
function ni { npm install @args }
function nci { npm ci @args }
function nb { npm run build @args }
function nt { npm test @args }
function pn { pnpm @args }
function b { bun @args }

function dnr { dotnet run @args }
function dnb { dotnet build @args }
function dnt { dotnet test @args }
function dnw { dotnet watch run @args }
function dnrs { dotnet restore @args }
function dnef { dotnet ef @args }

function serve-here {
    [CmdletBinding()]
    param([int]$Port = 5173)

    if (Get-Command bunx -ErrorAction SilentlyContinue) { bunx serve -l $Port; return }
    if (Get-Command npx -ErrorAction SilentlyContinue) { npx serve -l $Port; return }
    Write-Warning "Install node or bun to serve this folder."
}
