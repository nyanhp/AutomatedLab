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


}

function Remove-LWLibVirtNetworkSwitch
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
}

function Get-LWLibVirtNetworkSwitch
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
}

