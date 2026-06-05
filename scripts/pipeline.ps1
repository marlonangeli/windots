[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$CommandArgs)

& (Join-Path $PSScriptRoot "ilegna.ps1") pipeline @CommandArgs
