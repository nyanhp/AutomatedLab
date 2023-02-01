param 
(
    [string]
    $Repository = 'PSGallery'
)

$modules = @('Pester', 'PSScriptAnalyzer', 'PlatyPs', 'PSFramework', 'powershell-yaml', 'SHiPS')
Get-Module -ListAvailable -Name $modules

foreach ($module in $modules) {
    Write-Host "Installing $module" -ForegroundColor Cyan
    Install-Module $module -Force -SkipPublisherCheck -Repository $Repository -ErrorAction SilentlyContinue
    Import-Module $module -Force -ErrorAction SilentlyContinue
}

$gvp = New-Item -Path $home -Name gitversion -ItemType Directory -ErrorAction SilentlyContinue -Force
dotnet tool install GitVersion.Tool --version 5.* --tool-path $gvp.FullName *>$null
