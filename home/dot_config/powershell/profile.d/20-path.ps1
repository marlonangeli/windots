Add-PathEntryIfMissing -PathEntry (Join-Path $HOME ".local\bin")
Add-PathEntryIfMissing -PathEntry (Join-Path $env:LOCALAPPDATA "mise\shims")
Add-PathEntryIfMissing -PathEntry (Join-Path $HOME ".dotnet\tools")
Add-PathEntryIfMissing -PathEntry (Join-Path $HOME ".cargo\bin")
Add-PathEntryIfMissing -PathEntry (Join-Path $HOME "go\bin")
Add-PathEntryIfMissing -PathEntry (Join-Path $env:USERPROFILE ".bun\bin")
Add-PathEntryIfMissing -PathEntry (Join-Path $env:LOCALAPPDATA "Programs\jira-cli")
Add-PathEntryIfMissing -PathEntry "C:\tools\jira-cli"
