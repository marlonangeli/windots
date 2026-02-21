[CmdletBinding()]
param()

$scriptsRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $scriptsRoot "common\logging.ps1")

function Invoke-WindotsModuleAI {
    [CmdletBinding()]
    param(
        [hashtable]$Context = @{}
    )

    # TODO: mover script de link para o módulo em específico
    $scriptPath = Join-Path $scriptsRoot "link-ai-configs.ps1"
    if (-not (Test-Path $scriptPath)) {
        throw "[ai] Missing script: $scriptPath"
    }

    if ($Context.WhatIf) {
        Log-Info "[ai] WhatIf: would sync AI configs."
        return
    }

    Log-Step "[ai] Syncing AI configs"
    if ($Context.UseSymlinkAI) {
        & $scriptPath -UseSymlink
    }
    else {
        & $scriptPath
    }

    if ($LASTEXITCODE -ne 0) {
        throw "[ai] link-ai-configs failed with exit code $LASTEXITCODE"
    }

    # TODO: falta instalação e configuração de ferramentas de AI como codex, opencode Copilot CLI etc.
}
