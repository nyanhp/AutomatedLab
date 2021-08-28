Param (
    [Parameter(Mandatory)]
    [String]$AdkDownloadURL,

    [Parameter(Mandatory)]
    [String]$AdkDownloadPath,

    [Parameter(Mandatory)]
    [String]$WinPEDownloadURL,

    [Parameter(Mandatory)]
    [String]$WinPEDownloadPath
)

Write-ScreenInfo -Message "Starting ADK and WinPE download process" -TaskStart

$adkFile = Get-LabInternetFile -Uri $AdkDownloadURL -Path $labsources\SoftwarePackages -FileName adk.exe -PassThru -NoDisplay
$adkpeFile = Get-LabInternetFile -Uri $WinPEDownloadURL -Path $labsources\SoftwarePackages -FileName adkpe.exe -PassThru -NoDisplay

if ($(Get-Lab).DefaultVirtualizationEngine -eq 'Azure')
{
    Install-LabSoftwarePackage -Path $adkFile.FullName -ComputerName $ComputerName -CommandLine '/quiet /layout c:\ADKoffline' -NoDisplay
    Install-LabSoftwarePackage -Path $adkpeFile.FullName -ComputerName $ComputerName -CommandLine '/quiet /layout c:\ADKPEoffline' -NoDisplay
}
else
{
    Start-Process -FilePath $adkFile.FullName -ArgumentList "/quiet /layout $(Join-Path (Get-LabSourcesLocation -Local) Tools/ADKoffline)" -Wait -NoNewWindow
    Start-Process -FilePath $adkpeFile.FullName -ArgumentList " /quiet /layout $(Join-Path (Get-LabSourcesLocation -Local) Tools/ADKPEoffline)" -Wait -NoNewWindow
    Copy-LabFileItem -Path (Join-Path (Get-LabSourcesLocation -Local) Tools/ADKoffline) -ComputerName $ComputerName
    Copy-LabFileItem -Path (Join-Path (Get-LabSourcesLocation -Local) Tools/ADKPEoffline) -ComputerName $ComputerName
}

Install-LabSoftwarePackage -LocalPath C:\ADKOffline\adksetup.exe -ComputerName $ComputerName -CommandLine '/norestart /q /ceip off /features OptionId.DeploymentTools OptionId.UserStateMigrationTool OptionId.ImagingAndConfigurationDesigner' -NoDisplay
Install-LabSoftwarePackage -LocalPath C:\ADKPEOffline\adkwinpesetup.exe -ComputerName $ComputerName -CommandLine '/norestart /q /ceip off /features OptionId.WindowsPreinstallationEnvironment' -NoDisplay

# Workaround because Write-Progress doesn't yet seem to clear up from Get-LabInternetFile
Write-Progress -Activity * -Completed

Write-ScreenInfo -Message "Finished ADK / WinPE download process" -TaskEnd