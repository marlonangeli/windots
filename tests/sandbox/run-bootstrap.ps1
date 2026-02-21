[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-Location "C:\Users\WDAGUtilityAccount\Desktop\windots"

pwsh ./scripts/bootstrap.ps1 -Mode full -NoPrompt
if ($LASTEXITCODE -ne 0) { throw "bootstrap failed" }

pwsh ./scripts/validate.ps1
if ($LASTEXITCODE -ne 0) { throw "validate failed" }

Write-Host "Sandbox bootstrap + validation completed." -ForegroundColor Green
