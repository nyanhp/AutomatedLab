param
(
    [string]
    $ProjectRoot = $env:GITHUB_WORKSPACE
)

if ([string]::IsNullOrWhiteSpace($ProjectRoot))
{
    $ProjectRoot = (Resolve-Path -Path $PSScriptRoot/..).Path
}

$version = dotnet-gitversion | ConvertFrom-Json
dotnet-gitversion /l console /output buildserver /updateprojectfiles

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

dotnet build "$ProjectRoot/LabXml/LabXml.csproj"
dotnet publish "$ProjectRoot/LabXml/LabXml.csproj" -f net462 -o "$ProjectRoot/AutomatedLab/lib/full"
dotnet publish "$ProjectRoot/LabXml/LabXml.csproj" -f net6.0 -o "$ProjectRoot/AutomatedLab/lib/core"

Write-Host "Building child modules"
$sep = if ($IsLinux) { ':' } else { ';' }
$env:PSModulePath = "$ProjectRoot$sep$env:PSModulePath"
$modulesToBuild = 'AutomatedLab.Recipe', 'AutomatedLabNotifications', 'AutomatedLabUnattended'
foreach ($child in (Get-ChildItem -Directory -Path $env:APPVEYOR_BUILD_FOLDER | Where-Object Name -in $modulesToBuild))
{
    Write-Host -ForegroundColor DarkMagenta "Building $($child.Name)"
    & (Join-Path -Path $child.FullName -ChildPath '.build/build.ps1')
}