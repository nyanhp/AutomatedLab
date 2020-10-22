function New-LWLibVirtVirtualSwitch
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

function Remove-LWLibVirtVirtualSwitch
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

function Get-LWLibVirtVirtualSwitch
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

