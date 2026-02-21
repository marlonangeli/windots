[CmdletBinding()]
param()

$scriptsRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $scriptsRoot "common\logging.ps1")

function Invoke-WindotsModuleSecrets {
    [CmdletBinding()]
    param(
        [hashtable]$Context = @{}
    )

    if ($Context.SkipSecretsChecks) {
        Log-Info "[secrets] Skipped because -SkipSecretsChecks was set."
        return
    }

    # TODO: mover scripts para o modulo de secrets, e não deixar scripts genéricos na raiz. Talvez o módulo de secrets deva expor uma função Get-RequiredScripts ou algo assim, e o script de instalação deveria validar se os scripts necessários estão presentes.
    $migratePath = Join-Path $scriptsRoot "migrate-secrets.ps1"
    $depsPath = Join-Path $scriptsRoot "check-secrets-deps.ps1"

    if ($Context.WhatIf) {
        Log-Info "[secrets] WhatIf: would run secret migration and dependency checks."
        return
    }

    if (Test-Path $migratePath) {
        Log-Step "[secrets] Running migration checks"
        & $migratePath
        if ($LASTEXITCODE -ne 0) {
            throw "[secrets] migrate-secrets failed with exit code $LASTEXITCODE"
        }
    }

    if (Test-Path $depsPath) {
        Log-Step "[secrets] Running dependency checks"
        & $depsPath
        if ($LASTEXITCODE -ne 0) {
            throw "[secrets] check-secrets-deps failed with exit code $LASTEXITCODE"
        }
    }
}
