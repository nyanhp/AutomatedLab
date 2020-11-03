function Get-LWLibVirtVmStatus
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [string[]]
        $ComputerName
    )

    Write-LogFunctionEntry

    $libVirtVm = PoshLibVirt\Get-Vm -All

    $vmTable = @{ }
    Get-LabVm -IncludeLinux | Where-Object FriendlyName -in $ComputerName | ForEach-Object { $vmTable[$_.FriendlyName] = $_.Name }

    foreach ($vm in $libVirtVm)
    {
        $vmName = if ($vmTable[$vm.Name]) { $vmTable[$vm.Name] } else { $vm.Name }
        if ($vm.PowerState -eq 'Running')
        {
            $result.Add($vmName, 'Started')
        }
        elseif ($vm.PowerState -in 'Stopped', 'Dying', 'Shutdown', 'Paused')
        {
            $result.Add($vmName, 'Stopped')
        }
        else
        {
            $result.Add($vmName, 'Unknown')
        }
    }

    $result
    Write-LogFunctionExit
}

function New-LWLibVirtVm
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [AutomatedLab.Machine]
        $Machine
    )
}

function Remove-LWLibVirtVm
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline)]
        [AutomatedLab.Machine]
        $Machine
    )

    Write-LogFunctionEntry

    PoshLibVirt\Get-VM -ComputerName $Machine.ResourceName | PoshLibVirt\Remove-Vm -Storage -Confirm:$false

    Write-LogFunctionExit
}

function Start-LWLibVirtVm
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [AutomatedLab.Machine]
        $Machine
    )

    Write-LogFunctionEntry

    PoshLibVirt\Get-VM -ComputerName $Machine.ResourceName | PoshLibVirt\Start-Vm 

    Write-LogFunctionExit
}

function Stop-LWLibVirtVm
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [string[]]
        $ComputerName,

        [int]$DelayBetweenComputers = 0,

        [int]$PreDelaySeconds = 0,

        [int]$PostDelaySeconds = 0,

        [int]$ProgressIndicator,

        [switch]$NoNewLine
    )

    Write-LogFunctionEntry

    if ($PreDelay)
    {
        $job = Start-Job -Name 'Start-LWLibVirtVm - Pre Delay' -ScriptBlock { Start-Sleep -Seconds $Using:PreDelaySeconds }
        Wait-LWLabJob -Job $job -NoNewLine -ProgressIndicator $ProgressIndicator -Timeout 15 -NoDisplay
    }

    PoshLibVirt\Get-VM -ComputerName $Machine.ResourceName | PoshLibVirt\Remove-Vm -Storage -Confirm:$false

    if ($PostDelay)
    {
        $job = Start-Job -Name 'Start-LWLibVirtVm - Post Delay' -ScriptBlock { Start-Sleep -Seconds $Using:PostDelaySeconds }
        Wait-LWLabJob -Job $job -NoNewLine:$NoNewLine -ProgressIndicator $ProgressIndicator -Timeout 15 -NoDisplay
    }

    Write-LogFunctionExit    
}

function Save-LWLibVirtVm
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [AutomatedLab.Machine]
        $Machine
    )

    Write-LogFunctionEntry

    PoshLibVirt\Get-Vm -ComputerName $Machine.ResourceName | PoshLibVirt\Suspend-Vm

    Write-LogFunctionExit
}

function Checkpoint-LWLibVirtVm
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [AutomatedLab.Machine]
        $Machine
    )
}

function Restore-LWLibVirtVmSnapshot
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [AutomatedLab.Machine]
        $Machine
    )
}

