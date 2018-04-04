function Invoke-HyperVLabDeploymentTest
{
    [CmdletBinding()]
    param 
    ( 
        [Parameter(Mandatory)]
        [AutomatedLab.Lab]
        $Lab 
    )

    Describe ('Testing general deployment of lab {0}' -f $lab) {
        Context 'Should have the appropriate network adapters configured' {
            foreach ($adapter in $Lab.VirtualNetworks.Name)
            {
                It "Should have deployed VSwitch $adapter" {
                    Get-VMSwitch -Name $adapter | Should Not Be $null
                }
            }
        }
    
        Context "All VMs should be deployed" {
            foreach ($machine in $Lab.Machines)
            {
                It "Should have deployed VM $machine" {
                    Get-Vm -Name $machine.Name | Should Not Be $null
                    {Get-Vm -Name $machine.Name} | Should Not Throw
                }
            }
        }

        Context "Host file entries should exist" {
            foreach ($machine in $Lab.Machines)
            {
                It "Should have machine host entry" {
                    (Get-HostEntry -HostName $machine.Name).HostName | Should Be $machine.Name
                }

                It "Should point to the correct IP" {
                    (Get-HostEntry -HostName $machine.Name).IpAddress.ToString() | Should Be $machine.Ipv4Address
                }

                if ($machine.IsDomainJoined)
                {
                    It "Should have FQDN host entry" {
                        (Get-HostEntry -HostName $machine.Name).HostName | Should Be $machine.Name
                    }
    
                    It "FQDN Should point to the correct IP" {
                        (Get-HostEntry -HostName $machine.Name).IpAddress.ToString() | Should Be $machine.Ipv4Address
                    }
                }
            }
        }
    }
}
