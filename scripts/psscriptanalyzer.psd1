@{
    Rules = @{
        PSUseConsistentIndentation = @{
            Enable = $true
            Kind = "space"
            IndentationSize = 4
        }
        PSPlaceOpenBrace = @{
            Enable = $true
            OnSameLine = $true
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
        }
        PSPlaceCloseBrace = @{
            Enable = $true
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
        }
    }
}
