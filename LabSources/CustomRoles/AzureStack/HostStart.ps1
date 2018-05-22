param
(
    [string]
    $Version = '1804-1'
)

$downloadUris = @(
    'https://azurestack.azureedge.net/asdk$Version/AzureStackDownloader.exe'
    'https://azurestack.azureedge.net/asdk$Version/AzureStackDevelopmentKit-1.bin'
    'https://azurestack.azureedge.net/asdk$Version/AzureStackDevelopmentKit-2.bin'
    'https://azurestack.azureedge.net/asdk$Version/AzureStackDevelopmentKit-3.bin'
    'https://azurestack.azureedge.net/asdk$Version/AzureStackDevelopmentKit-4.bin'
    'https://azurestack.azureedge.net/asdk$Version/AzureStackDevelopmentKit-5.bin'
    'https://azurestack.azureedge.net/asdk$Version/AzureStackDevelopmentKit-6.bin'
)

$labsourcesVolume = [System.IO.DriveInfo](Get-LabSourcesLocationInternal -Local).SubString(0,1)

if (-not $labsourcesVolume.AvailableFreeSpace -gt 60GB)
{
    $labSourcesVolume = [System.IO.DriveInfo](Get-Volume | Where-Object -FilterScript {$_.DriveLetter -and $_.SizeRemaining -gt 60GB} | Select-Object -First 1).DriveLetter.ToString()
    Write-Verbose -Message 'Lab sources location {0} did not have 60GB available. Chosen volume {1} instead.' -f (Get-LabSourcesLocationInternal -Local),$labsourcesVolume.Name
}

$downloadPath = Join-Path -Path $labsourcesVolume -ChildPath '\LabSources\CustomRoles\AzureStack\Binaries'

if (-not (Test-Path $downloadPath -ErrorAction SilentlyContinue))
{
    [void] (New-Item -ItemType Directory -Path $downloadPath -Force)
}

foreach ($uri in $downloadUris)
{
    Write-Verbose -Message 'Downloading 11GB of data. This might take some time.'
    Get-LabInternetFile -Uri $uri -Path $downloadPath
}

