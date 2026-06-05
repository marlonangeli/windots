if (-not (Test-InteractiveShell)) { return }

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-ShellInitScript -Command "zoxide" -Arguments @("init", "powershell") | Out-Null
}

if ($env:MISE_ACTIVATE -eq "1" -and (Get-Command mise -ErrorAction SilentlyContinue)) {
    Invoke-ShellInitScript -Command "mise" -Arguments @("activate", "pwsh") | Out-Null
}

if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-ShellInitScript -Command "starship" -Arguments @("init", "powershell") | Out-Null
}
