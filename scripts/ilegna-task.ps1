[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$CommandArgs)

& (Join-Path $PSScriptRoot "ilegna-workflow.ps1") task @CommandArgs
