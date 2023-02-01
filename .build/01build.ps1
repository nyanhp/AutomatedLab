param
(
    [string]
    $ProjectRoot = $env:GITHUB_WORKSPACE
)

if ([string]::IsNullOrWhiteSpace($ProjectRoot))
{
    $ProjectRoot = (Resolve-Path -Path $PSScriptRoot/..).Path
}

$sep = if ($IsLinux) { ':' } else { ';' }
$env:PATH = "$(Join-Path $ProjectRoot gitversion)$sep$env:PATH"
$env:PSModulePath = "$ProjectRoot$sep$env:PSModulePath"

$version = dotnet-gitversion | ConvertFrom-Json
$null = dotnet-gitversion /l console /output buildserver /updateprojectfiles

foreach ($item in (Get-ChildItem -Path $ProjectRoot -Filter *.psd1 -Recurse))
{
    if ($item.BaseName -notin 'AutomatedLab','AutomatedLab.Recipe','AutomatedLab.Ships','AutomatedLabDefinition','AutomatedLabNotifications','AutomatedLabTest','AutomatedLabUnattended','AutomatedLabWorker','HostsFile','PSLog','PSFileTransfer') { continue }
    if ($item.Directory.Name -eq $item.BaseName)
    {
        $content = Get-Content $item.FullName
        $content = $content -replace "^\s*ModuleVersion += '\d\.\d\.\d'", "ModuleVersion = '$($version.MajorMinorPatch)'"
        if (-not [string]::IsNullOrWhiteSpace($version.NuGetPreReleaseTagV2))
        {
            $content = $content -replace "Prerelease\s+=\s+''", "Prerelease = '$($version.NuGetPreReleaseTagV2)'"
        }
        $content | Set-Content -Path $item.FullName
    }
}

$null = dotnet build "$ProjectRoot/LabXml/LabXml.csproj"
$null = dotnet publish "$ProjectRoot/LabXml/LabXml.csproj" -f net462 -o "$ProjectRoot/AutomatedLab/lib/full"
$null = dotnet publish "$ProjectRoot/LabXml/LabXml.csproj" -f net6.0 -o "$ProjectRoot/AutomatedLab/lib/core"

Write-Host "Building child modules"
$modulesToBuild = 'AutomatedLab.Recipe', 'AutomatedLabNotifications', 'AutomatedLabUnattended'
foreach ($child in (Get-ChildItem -Directory -Path $ProjectRoot | Where-Object Name -in $modulesToBuild))
{
    Write-Host -ForegroundColor DarkMagenta "Building $($child.Name)"
    & (Join-Path -Path $child.FullName -ChildPath '.build/build.ps1')
}

if ([System.Environment]::OSVersion.Platform -eq 'Win32NT')
{
    dotnet build $ProjectRoot\AutomatedLab.sln -c Debug
}

if ([System.Environment]::OSVersion.Platform -eq 'Unix')
{
    $null = New-Item -ItemType Directory -Path ./deb/automatedlab/usr/local/share/powershell/Modules -Force
    $null = New-Item -ItemType Directory -Path ./deb/automatedlab/usr/share/AutomatedLab/Assets -Force
    $null = New-Item -ItemType Directory -Path ./deb/automatedlab/usr/share/AutomatedLab/Stores -Force
    $null = New-Item -ItemType Directory -Path ./deb/automatedlab/usr/share/AutomatedLab/Labs -Force
    $null = New-Item -ItemType Directory -Path ./deb/automatedlab/usr/share/AutomatedLab/LabSources -Force
    $null = New-Item -ItemType Directory -Path ./deb/automatedlab/DEBIAN -Force

    # Create control file
    @"
Package: automatedlab
Version: $($version.NuGetVersionV2)
Maintainer: https://automatedlab.org
Description: Installs the pwsh module AutomatedLab in the global module directory
Section: utils
Architecture: amd64
Bugs: https://github.com/automatedlab/automatedlab/issues
Homepage: https://automatedlab.org
Pre-Depends: powershell
Installed-Size: $('{0:0}' -f ((Get-ChildItem -Path $ProjectRoot -Exclude .git -File -Recurse | Measure-Object Length -Sum).Sum /1mb))
"@ | Set-Content -Path ./deb/automatedlab/DEBIAN/control -Encoding UTF8

    # Copy content
    $modTemp = Join-Path -Path $ProjectRoot -ChildPath 'deb/automatedlab/usr/local/share/powershell/Modules'
    $sources = 'AutomatedLab', 'AutomatedLab.Recipe', 'AutomatedLab.Ships', 'AutomatedLabDefinition', 'AutomatedLabNotifications', 'AutomatedLabTest', 'AutomatedLabUnattended', 'AutomatedLabWorker', 'HostsFile', 'PSLog', 'PSFileTransfer'
    foreach ($source in $sources)
    {
        $sourcePath = Join-Path -Path $ProjectRoot -ChildPath "$($source)/*"
        $modulepath = Join-Path -Path $modTemp -ChildPath "$($source)/$($version.MajorMinorPatch)"
        $null = New-Item -ItemType Directory -Path $modulePath -Force
        Copy-Item -Path $sourcePath -Destination $modulePath -Force -Recurse
    }

    Save-Module -Repository PSGallery -Name AutomatedLab.Common, newtonsoft.json, Ships, PSFramework, xPSDesiredStateConfiguration, xDscDiagnostics, xWebAdministration -Path $modTemp

    # Pre-configure LabSources for the user
    $confPath = Join-Path -Path $modTemp -ChildPath "AutomatedLab/$($version.MajorMinorPatch)/AutomatedLab.init.ps1"
    Add-Content -Path $confPath -Value 'Set-PSFConfig -Module AutomatedLab -Name LabSourcesLocation -Description "Location of lab sources folder" -Validation string -Value "/usr/share/AutomatedLab/LabSources"'

    Copy-Item -Path (Join-Path -Path $ProjectRoot -ChildPath 'Assets/*') -Recurse -Destination ./deb/automatedlab/usr/share/AutomatedLab/Assets -Force
    Copy-Item -Path (Join-Path -Path $ProjectRoot -ChildPath 'LabSources/*') -Recurse -Destination ./deb/automatedlab/usr/share/AutomatedLab/LabSources -Force

    # Update permissions on AL folder to allow non-root access to configs
    chmod -R 775 ./deb/automatedlab/usr/share/AutomatedLab

    # Build debian package and convert it to RPM
    dpkg-deb --build ./deb/automatedlab automatedlab_NONSTABLEBETA_$($version.NuGetVersionV2)_x86_64.deb
    sudo alien -r automatedlab_NONSTABLEBETA_$($version.NuGetVersionV2)_x86_64.deb
    Rename-Item -Path "*.rpm" -NewName automatedlab_NONSTABLEBETA_$($version.NuGetVersionV2)_x86_64.rpm
}
