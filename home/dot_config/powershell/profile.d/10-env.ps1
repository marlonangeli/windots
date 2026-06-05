$env:DOTNET_CLI_TELEMETRY_OPTOUT = "1"
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = "1"
$env:POWERSHELL_TELEMETRY_OPTOUT = "1"
$env:MISE_NOT_FOUND_AUTO_INSTALL = "0"

if ([string]::IsNullOrWhiteSpace($env:EDITOR)) { $env:EDITOR = "zed" }
if ([string]::IsNullOrWhiteSpace($env:VISUAL)) { $env:VISUAL = $env:EDITOR }

if (Test-InteractiveShell) {
    Set-PSReadLineOption -EditMode Windows -PredictionSource History -PredictionViewStyle ListView -HistorySearchCursorMovesToEnd -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward -ErrorAction SilentlyContinue
}
