function Install-LabHyperV
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseCompatibleCmdlets", "", Justification="Not relevant on Linux")]
    [CmdletBinding()]
    param
    ( )

    Write-LogFunctionEntry

    $vms = Get-LabVm -Role HyperV

    Write-ScreenInfo -Message 'Exposing virtualization extensions...' -NoNewLine
    $hyperVVms = $vms | Where-Object -Property HostType -eq HyperV
    if ($hyperVVms)
    {
        $enableVirt = $vms | Where-Object {-not ($_ | Get-VmProcessor).ExposeVirtualizationExtensions}
        if ($null -ne $enableVirt)
        {
            Stop-LabVm -Wait -ComputerName $enableVirt
            $enableVirt | Set-VMProcessor -ExposeVirtualizationExtensions $true
            $enableVirt | Get-VMNetworkAdapter | Set-VMNetworkAdapter -MacAddressSpoofing On
        }
    }

    Start-LabVm -Wait -ComputerName $vms # Start all, regardless of Hypervisor
    Write-ScreenInfo -Message 'Done'

    # Enable Feature
    Write-ScreenInfo -Message "Enabling Hyper-V feature and waiting for restart of $($vms.Count) VMs..." -NoNewLine

    $clients, $servers = $vms.Where({$_.OperatingSystem.Installation -eq 'Client'}, 'Split')

    $jobs = @()

    if ($clients)
    {
        $jobs += Install-LabWindowsFeature -ComputerName $clients -FeatureName Microsoft-Hyper-V-All -NoDisplay -AsJob -PassThru
    }

    if ($servers)
    {
        $jobs += Install-LabWindowsFeature -ComputerName $servers -FeatureName Hyper-V -IncludeAllSubFeature -IncludeManagementTools -NoDisplay -AsJob -PassThru
    }

    Wait-LWLabJob -Job $jobs

    # Restart
    Restart-LabVm -ComputerName $vms -Wait -NoDisplay
    Write-ScreenInfo -Message 'Done'

    $jobs = foreach ($vm in $vms)
    {
        Invoke-LabCommand -ActivityName 'Configuring VM Host settings' -ComputerName $vm -Variable (Get-Variable -Name vm) -ScriptBlock {
            Import-Module Hyper-V
            # Correct data types for individual settings
            $parametersAndTypes = @{
                MaximumStorageMigrations                  = [uint32]
                MaximumVirtualMachineMigrations           = [uint32]
                VirtualMachineMigrationAuthenticationType = [Microsoft.HyperV.PowerShell.MigrationAuthenticationType]
                UseAnyNetworkForMigration                 = [bool]
                VirtualMachineMigrationPerformanceOption  = [Microsoft.HyperV.PowerShell.VMMigrationPerformance]
                ResourceMeteringSaveInterval              = [timespan]
                NumaSpanningEnabled                       = [bool]
                EnableEnhancedSessionMode                 = [bool]
            }

            [hashtable]$roleParameters = ($vm.Roles | Where-Object Name -eq HyperV).Properties
            if ($roleParameters.Count -eq 0) { continue }
            $parameters = Sync-Parameter -Command (Get-Command Set-VMHost) -Parameters $roleParameters
            
            foreach ($parameter in $parameters.Clone().GetEnumerator())
            {
                $type = $parametersAndTypes[$parameter.Key]

                if ($type -eq [bool])
                {
                    $parameters[$parameter.Key] = [Convert]::ToBoolean($parameter.Value)
                }
                else
                {
                    $parameters[$parameter.Key] = $parameter.Value -as $type
                }
            }

            Set-VMHost @parameters
        } -Function (Get-Command -Name Sync-Parameter) -AsJob -PassThru -IgnoreAzureLabSources
    }

    Wait-LWLabJob -Job $jobs

    Write-LogFunctionExit
}

function Connect-LabHyperV
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory,ParameterSetName='NewSession')]
        [string]
        $ComputerName,

        [Parameter(ParameterSetName='NewSession')]
        [pscredential]
        $Credential,

        [Parameter(ParameterSetName='NewSession')]
        [Microsoft.Management.Infrastructure.Options.PasswordAuthenticationMechanism]
        $Authentication,

        [Parameter(ParameterSetName='NewSession')]
        [string]
        $Name,

        [Parameter(ParameterSetName='NewSession')]
        [uint32]
        $OperationTimeoutSec,

        [Parameter(ParameterSetName='NewSession')]
        [switch]
        $SkipTestConnection,

        [Parameter(ParameterSetName='NewSession')]
        [uint32]
        $Port,

        [Parameter(ParameterSetName='NewSession')]
        [Microsoft.Management.Infrastructure.Options.CimSessionOptions]
        $SessionOption,

        [Parameter(ParameterSetName='ExistingSession')]
        [CimSession]
        $Session
    )

    $cimSession = if ($PSCmdlet.ParameterSetName -eq 'ExistingSession')
    {
        $Session
    }
    else
    {
        New-CimSession @PSBoundParameters
    }

    $PSDefaultParameterValues.Add('Hyper-V\*:CimSession' = $cimSession)
}