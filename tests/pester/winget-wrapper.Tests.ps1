BeforeAll {
    $scriptsRoot = Join-Path $PSScriptRoot "..\..\scripts"
    . (Join-Path $scriptsRoot "common\logging.ps1")
    . (Join-Path $scriptsRoot "common\winget.ps1")
}

Describe "Winget wrapper" {
    BeforeEach {
        $script:calls = @()
        Mock -CommandName Get-Command -ParameterFilter { $Name -eq "winget" } -MockWith {
            [pscustomobject]@{
                Name = "winget"
                Source = "winget.exe"
            }
        }
    }

    It "always appends --source winget for installs" {
        Mock -CommandName winget -MockWith {
            $script:calls += ,@($args)
            $global:LASTEXITCODE = 0
            "ok"
        }

        Invoke-WingetInstall -Id "Git.Git"

        $script:calls.Count | Should -Be 1
        ($script:calls[0] -join " ") | Should -Match "--source winget"
        ($script:calls[0] -join " ") | Should -Match "--accept-source-agreements"
        ($script:calls[0] -join " ") | Should -Match "--accept-package-agreements"
    }

    It "applies fallback plan when msstore certificate failure is detected" {
        Mock -CommandName winget -MockWith {
            $script:calls += ,@($args)
            if ($script:calls.Count -eq 1) {
                $global:LASTEXITCODE = 1
                "0x8a15005e Failed when searching source: msstore"
                return
            }

            $global:LASTEXITCODE = 0
            "ok"
        }

        Invoke-WingetInstall -Id "Git.Git"

        $commands = $script:calls | ForEach-Object { $_ -join " " }
        ($commands -join [Environment]::NewLine) | Should -Match "source disable --name msstore"
        $script:calls.Count | Should -BeGreaterThan 2
    }
}
