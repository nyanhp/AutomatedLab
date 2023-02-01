param 
(
    [string]
    $Repository = 'PSGallery'
)

$modules = @('Pester', 'PSScriptAnalyzer', 'PlatyPs', 'PSFramework', 'powershell-yaml', 'SHiPS')

foreach ($module in $modules) {
    Write-Host "Installing $module" -ForegroundColor Cyan
    Install-Module $module -Force -SkipPublisherCheck -Repository $Repository
    Import-Module $module -Force
}

$gvp = New-Item -Path $home -Name gitversion -ItemType Directory -ErrorAction SilentlyContinue
$sep = if ($IsLinux) { ':' } else { ';' }
dotnet tool install GitVersion.Tool --version 5.* --tool-path $gvp.FullName *>$null
$env:PATH = "$($gvp.FullName)$sep$env:PATH"
