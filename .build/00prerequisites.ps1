param 
(
    [string]
    $ProjectRoot = $env:GITHUB_WORKSPACE,

    [string]
    $Repository = 'PSGallery'
)

if ([string]::IsNullOrWhiteSpace($ProjectRoot))
{
    $ProjectRoot = (Resolve-Path -Path $PSScriptRoot/..).Path
}

$modules = @('Pester', 'PSScriptAnalyzer', 'PlatyPs', 'PSFramework', 'powershell-yaml', 'SHiPS')
Get-Module -ListAvailable -Name $modules

foreach ($module in $modules) {
    Write-Host "Installing $module" -ForegroundColor Cyan
    Install-Module $module -Force -SkipPublisherCheck -Repository $Repository -ErrorAction SilentlyContinue
    Import-Module $module -Force -ErrorAction SilentlyContinue
}

if ($IsLinux)
{
    sudo apt update
    sudo apt install alien -y
}

$gvp = New-Item -Path $ProjectRoot -Name gitversion -ItemType Directory -ErrorAction SilentlyContinue -Force
dotnet tool install GitVersion.Tool --version 5.* --tool-path $gvp.FullName

$sep = if ($IsLinux) { ':' } else { ';' }
$env:PATH = "$($gvp.FullName)$sep$env:PATH"
$env:PSModulePath = "$ProjectRoot$sep$env:PSModulePath"
