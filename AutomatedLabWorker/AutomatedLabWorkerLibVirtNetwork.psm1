function New-LWLibVirtNetworkSwitch
{
    [CmdletBinding()]
    param
    (        
        [Parameter(Mandatory)]
        [AutomatedLab.VirtualNetwork[]]
        $VirtualNetwork,

        [switch]
        $PassThru
    )

    Write-LogFunctionEntry

    foreach ($network in $VirtualNetwork)
    {
        $ipEntry = [PoshLibVirt.IpEntry]::new()
        $ipEntry.IpAddress = $network.AddressSpace.IpAddress.AddressAsString
        $ipEntry.NetworkMask = $network.AddressSpace.Netmask

        $config = New-PoshLibVirtNetworkConfiguration -Name $network.ResourceName -BridgeName $network.ResourceName -IpAddresses $ipEntry
        $null = New-VirtualNetwork -Network $config
    }

    if ($PassThru)
    {
        Get-LWLibVirtNetworkSwitch -VirtualNetwork $VirtualNetwork
    }

    Write-LogFunctionExit
}

function Remove-LWLibVirtNetworkSwitch
{
    [CmdletBinding()]
    param
    (        
        [Parameter(Mandatory)]
        [AutomatedLab.VirtualNetwork[]]
        $VirtualNetwork
    )

    Remove-VirtualNetwork -Name $VirtualNetwork.ResourceName
}

function Get-LWLibVirtNetworkSwitch
{
    [CmdletBinding()]
    param
    (        
        [Parameter(Mandatory)]
        [AutomatedLab.VirtualNetwork[]]
        $VirtualNetwork
    )

    Get-VirtualNetwork -Name $VirtualNetwork.ResourceName -ErrorAction SilentlyContinue
}

