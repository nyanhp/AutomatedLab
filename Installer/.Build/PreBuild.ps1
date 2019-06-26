param(
    [Parameter(Mandatory)]
    [string]$SolutionDir
)

Push-Location
	$null = Install-PackageProvider nuget -Force -Required 2.8.5.201

If ($ENV:BHBuildSystem -ne 'AppVeyor')
{
    Set-Location -Path $SolutionDir\AutomatedLab.Common
    git reset --hard
    git submodule -q update --init --recursive
    git pull origin master

    # Compile Common libary
    dotnet build $SolutionDir\AutomatedLab.Common

    # Compile Help
    If (-not (Get-Module -List PlatyPs))
    {
        Install-Module PlatyPS -Force -AllowClobber -SkipPublisherCheck
    }

	foreach ($moduleName in (Get-ChildItem -Path $SolutionDir\Help -Directory))
    {
        foreach ($language in ($moduleName | Get-ChildItem -Directory))
        {
            $ci = try { [cultureinfo]$language.BaseName} catch { }
            if (-not $ci) {continue}

            $opPath = Join-Path -Path $SolutionDir -ChildPath "$($moduleName.BaseName)\$($language.BaseName)"
            Write-Host "Generating help XML in $opPath"
            New-ExternalHelp -Path $language.FullName -OutputPath $opPath
        }
    }
    $null = New-ExternalHelp -Path $SolutionDir\AutomatedLab.Common\Help\en-us -OutputPath $SolutionDir\AutomatedLab.Common\AutomatedLab.Common\en-us

    Microsoft.PowerShell.Utility\Write-Host 'Creating backup of file AutomatedLab.Common.psd1'
    Copy-Item -Path $SolutionDir\AutomatedLab.Common\AutomatedLab.Common\AutomatedLab.Common.psd1 -Destination $SolutionDir\AutomatedLab.Common\AutomatedLab.Common\AutomatedLab.Common.psd1.original
}
else
{
    Remove-Item -Recurse -Path $SolutionDir\AutomatedLab.Common\AutomatedLab.Common -Force
    Save-Module -Name AutomatedLab -Path .\AutomatedLab.Common -Force
}

Microsoft.PowerShell.Utility\Write-Host 'Creating backup of file Includes.wxi'
Copy-Item -Path $SolutionDir\Installer\Includes.wxi -Destination $SolutionDir\Installer\Includes.wxi.original

$dllPath = Join-Path -Path $SolutionDir -ChildPath LabXml\bin\debug\net462
$automatedLabdll = Get-Item -Path "$dllPath\AutomatedLab.dll"
Microsoft.PowerShell.Utility\Write-Host "AutomatedLab Dll path is '$($automatedLabdll.FullName)'"
$alDllVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($automatedLabdll)
Microsoft.PowerShell.Utility\Write-Host "Product Version of AutomatedLab is '$($alDllVersion.FileVersion)'"

$alCommonVersion = (Find-Module -Name AutomatedLab.Common -ErrorAction SilentlyContinue).Version

Microsoft.PowerShell.Utility\Write-Host "Version of AutomatedLab.Common is '$alCommonVersion'"
Microsoft.PowerShell.Utility\Write-Host "Writing new 'Includes.wxi' file"
('<?xml version="1.0" encoding="utf-8"?><Include Id="VersionNumberInclude"><?define AutomatedLabCommonVersion="{0}" ?><?define AutomatedLabProductVersion="{1}" ?></Include>' -f $alCommonVersion, $alDllVersion.FileVersion) | Out-File -FilePath $SolutionDir\Installer\Includes.wxi -Encoding UTF8
Microsoft.PowerShell.Utility\Write-Host "Replacing version in 'AutomatedLab.Common.psd1' file"
(Get-Content -Path $SolutionDir\AutomatedLab.Common\AutomatedLab.Common\AutomatedLab.Common.psd1 -Raw) -replace "(ModuleVersion([ =]+))(')(?<Version>\d{1,2}\.\d{1,2}\.\d{1,2})", "`$1'$alCommonVersion" | Out-File -FilePath $SolutionDir\AutomatedLab.Common\AutomatedLab.Common\AutomatedLab.Common.psd1

Pop-Location

# Update installer
$commonDllCorePath = Join-Path -Path $SolutionDir -ChildPath 'AutomatedLab.Common\AutomatedLab.Common\lib\core'
$commonDllPath = Join-Path -Path $SolutionDir -ChildPath 'AutomatedLab.Common\AutomatedLab.Common\lib\full'
$dllCorePath = Join-Path -Path (Resolve-Path -Path $dllPath\..).Path -ChildPath 'netcoreapp2.2'

Microsoft.PowerShell.Utility\Write-Host "Locating libraries in $dllPath and $dllCorePath"
$newContentFull = Get-ChildItem -File -Filter *.dll -Path $dllPath | ForEach-Object { '<File Source="$(var.SolutionDir)LabXml\bin\debug\net462\{0}" Id="{1}" />' -f $_.Name, "full$((New-Guid).Guid -replace '-')" }
$newContentCore = Get-ChildItem -File -Filter *.dll -Path $dllCorePath | ForEach-Object { '<File Source="$(var.SolutionDir)LabXml\bin\debug\netcoreapp2.2\{0}" Id="{1}" />' -f $_.Name, "core$((New-Guid).Guid -replace '-')" }

Microsoft.PowerShell.Utility\Write-Host "Locating libraries in $commonDllPath and $commonDllCorePath"
$newContentCommonFull = Get-ChildItem -File -Filter *.dll -Path $commonDllPath | ForEach-Object { '<File Source="$(var.SolutionDir)AutomatedLab.Common\AutomatedLab.Common\lib\full\{0}" Id="{1}" />' -f $_.Name, "full$((New-Guid).Guid -replace '-')" }
$newContentCommonCore = Get-ChildItem -File -Filter *.dll -Path $commonDllCorePath | ForEach-Object { '<File Source="$(var.SolutionDir)AutomatedLab.Common\AutomatedLab.Common\lib\core\{0}" Id="{1}" />' -f $_.Name, "core$((New-Guid).Guid -replace '-')" }

Microsoft.PowerShell.Utility\Write-Host "Creating backup of file product.wxs"
Copy-Item -Path $SolutionDir\Installer\product.wxs -Destination $SolutionDir\Installer\product.wxs.original
(Get-Content $SolutionDir\Installer\product.wxs) -replace '<!-- %%%FILEPLACEHOLDERCOMMONCORE%%% -->', ($newContentCommonCore -join "`r`n") -replace '<!-- %%%FILEPLACEHOLDERCOMMONFULL%%% -->', ($newContentCommonFull -join "`r`n") -replace '<!-- %%%FILEPLACEHOLDERCORE%%% -->', ($newContentCore -join "`r`n") -replace '<!-- %%%FILEPLACEHOLDERFULL%%% -->', ($newContentFull -join "`r`n") | Set-Content $SolutionDir\Installer\Product.wxs -Encoding UTF8
