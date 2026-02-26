@{
    Version = '1.0.0'
    Providers = @('winget', 'mise')
    Packages = @(
        @{
            Name = 'chezmoi'
            Provider = 'winget'
            PackageId = 'twpayne.chezmoi'
            VerifyCommand = 'chezmoi'
            Modules = @('core')
            Modes = @('full', 'clean')
            Required = $true
        },
        @{
            Name = 'git'
            Provider = 'winget'
            PackageId = 'Git.Git'
            VerifyCommand = 'git'
            Modules = @('core')
            Modes = @('full', 'clean')
            Required = $true
        },
        @{
            Name = 'powershell'
            Provider = 'winget'
            PackageId = 'Microsoft.PowerShell'
            VerifyCommand = 'pwsh'
            Modules = @('core')
            Modes = @('full', 'clean')
            Required = $true
        },
        @{
            Name = 'windows-terminal'
            Provider = 'winget'
            PackageId = 'Microsoft.WindowsTerminal'
            VerifyPath = '$env:LOCALAPPDATA\\Packages\\Microsoft.WindowsTerminal_8wekyb3d8bbwe'
            Modules = @('terminal')
            Modes = @('full', 'clean')
            Required = $true
        },
        @{
            Name = 'github-cli'
            Provider = 'winget'
            PackageId = 'GitHub.cli'
            VerifyCommand = 'gh'
            Modules = @('core')
            Modes = @('full', 'clean')
            Required = $false
        },
        @{
            Name = 'oh-my-posh'
            Provider = 'winget'
            PackageId = 'JanDeDobbeleer.OhMyPosh'
            VerifyCommand = 'oh-my-posh'
            Modules = @('shell', 'themes')
            Modes = @('full', 'clean')
            Required = $true
        },
        @{
            Name = 'jetbrainsmono-nerdfont'
            Provider = 'winget'
            PackageId = 'DEVCOM.JetBrainsMonoNerdFont'
            VerifyPath = '$env:WINDIR\\Fonts\\JetBrainsMonoNerdFont-Regular.ttf'
            Modules = @('themes')
            Modes = @('full', 'clean')
            Required = $false
        },
        @{
            Name = 'mise'
            Provider = 'winget'
            PackageId = 'jdx.mise'
            VerifyCommand = 'mise'
            Modules = @('mise')
            Modes = @('full', 'clean')
            Required = $true
        },
        @{
            Name = 'gum'
            Provider = 'winget'
            PackageId = 'charmbracelet.gum'
            VerifyCommand = 'gum'
            Modules = @('core')
            Modes = @('full', 'clean')
            Required = $true
        },
        @{
            Name = 'azure-cli'
            Provider = 'winget'
            PackageId = 'Microsoft.AzureCLI'
            VerifyCommand = 'az'
            Modules = @('packages')
            Modes = @('full')
            Required = $false
        },
        @{
            Name = 'docker-desktop'
            Provider = 'winget'
            PackageId = 'Docker.DockerDesktop'
            VerifyPath = '$env:ProgramFiles\\Docker\\Docker\\Docker Desktop.exe'
            Modules = @('packages')
            Modes = @('full')
            Required = $false
        },
        @{
            Name = 'vscode'
            Provider = 'winget'
            PackageId = 'Microsoft.VisualStudioCode'
            VerifyCommand = 'code'
            Modules = @('packages')
            Modes = @('full')
            Required = $false
        },
        @{
            Name = 'zed'
            Provider = 'winget'
            PackageId = 'ZedIndustries.Zed'
            VerifyPath = '$env:LOCALAPPDATA\\Programs\\Zed\\Zed.exe'
            Modules = @('packages')
            Modes = @('full')
            Required = $false
        },
        @{
            Name = 'github-copilot'
            Provider = 'winget'
            PackageId = 'GitHub.Copilot'
            VerifyPath = '$env:LOCALAPPDATA\\Programs\\GitHub Copilot'
            Modules = @('ai')
            Modes = @('full')
            Required = $false
        },
        @{
            Name = 'bitwarden-cli'
            Provider = 'winget'
            PackageId = 'Bitwarden.CLI'
            VerifyCommand = 'bw'
            Modules = @('secrets')
            Modes = @('full', 'clean')
            Required = $false
        },
        @{
            Name = 'fzf'
            Provider = 'winget'
            PackageId = 'junegunn.fzf'
            VerifyCommand = 'fzf'
            Modules = @('packages')
            Modes = @('full', 'clean')
            Required = $false
        },
        @{
            Name = 'visual-studio-build-tools'
            Provider = 'winget'
            PackageId = 'Microsoft.VisualStudio.2022.BuildTools'
            VerifyPath = '${env:ProgramFiles(x86)}\\Microsoft Visual Studio\\2022\\BuildTools'
            ExtraArgs = @(
                '--override'
                '--quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --includeRecommended --includeOptional'
            )
            Modules = @('development')
            Modes = @('full')
            Required = $false
        },
        @{
            Name = 'mise-tool-dotnet'
            Provider = 'mise'
            PackageId = 'dotnet'
            VerifyCommand = 'dotnet'
            Modules = @('development')
            Modes = @('full', 'clean')
            Required = $false
        },
        @{
            Name = 'mise-tool-node'
            Provider = 'mise'
            PackageId = 'node'
            VerifyCommand = 'node'
            Modules = @('development')
            Modes = @('full', 'clean')
            Required = $false
        },
        @{
            Name = 'mise-tool-bun'
            Provider = 'mise'
            PackageId = 'bun'
            VerifyCommand = 'bun'
            Modules = @('development')
            Modes = @('full', 'clean')
            Required = $false
        },
        @{
            Name = 'mise-tool-python'
            Provider = 'mise'
            PackageId = 'python'
            VerifyCommand = 'python'
            Modules = @('development')
            Modes = @('full', 'clean')
            Required = $false
        },
        @{
            Name = 'mise-tool-ripgrep'
            Provider = 'mise'
            PackageId = 'ripgrep'
            VerifyCommand = 'rg'
            Modules = @('packages')
            Modes = @('full', 'clean')
            Required = $false
        },
        @{
            Name = 'mise-tool-fd'
            Provider = 'mise'
            PackageId = 'fd'
            VerifyCommand = 'fd'
            Modules = @('packages')
            Modes = @('full', 'clean')
            Required = $false
        },
        @{
            Name = 'mise-tool-bat'
            Provider = 'mise'
            PackageId = 'bat'
            VerifyCommand = 'bat'
            Modules = @('packages')
            Modes = @('full', 'clean')
            Required = $false
        },
        @{
            Name = 'mise-tool-zoxide'
            Provider = 'mise'
            PackageId = 'zoxide'
            VerifyCommand = 'zoxide'
            Modules = @('packages')
            Modes = @('full', 'clean')
            Required = $false
        },
        @{
            Name = 'mise-tool-usage'
            Provider = 'mise'
            PackageId = 'cargo:usage-cli'
            VerifyCommand = 'usage'
            Modules = @('development')
            Modes = @('full')
            Required = $false
        }
    )
}
