[CmdletBinding()]
param()

& (Join-Path $PSScriptRoot "ilegna.ps1") doctor
