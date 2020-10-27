Describe 'AutomatedLab Prerequisites' {

    $linuxRequiredTools = @(
        @{ Package = 'virt-install' }
        @{ Package = 'virsh' }
        @{ Package = 'ip' }
        @{ Package = 'bridge' }
        @{ Package = 'route' }
    )

    if (-not ($IsLinux -or $IsMacOS))
    {
        $winLabsources = @(@{LabSourcesLocation = Get-LabSourcesLocation -Local })
    }
    
    Context 'Generic' {
        It 'On Windows: Should be capable of connecting to remote systems' -Skip:$($IsLinux -or $IsMacOS) {
            Test-LabHostRemoting -ErrorAction SilentlyContinue | Should -BeTrue
        }

        It 'On Linux: Should be capable of connecting to remote systems' -Skip:$($IsWindows) {
            if (Get-Command -Name dnf -ErrorAction SilentlyContinue)
            {
                dnf list installed krb5-libs 2>$null | Should -Not -BeNullOrEmpty -Because 'GSSAPI libs are required'
            }
            elseif (Get-Command -Name yum -ErrorAction SilentlyContinue)
            {
                yum list installed krb5-libs 2>$null | Should -Not -BeNullOrEmpty -Because 'GSSAPI libs are required'
            }
            elseif (Get-Command -Name apt -ErrorAction SilentlyContinue)
            {
                apt -qq --installed list krb5-libs 2>$null | Should -Not -BeNullOrEmpty -Because 'GSSAPI libs are required'
            }
            else
            {
                $false | Should -BeTrue -Because 'We are unable to detect a supported distribution (i.e. neither dnf, yum nor apt found'
            }
        }
    }

    Context 'Hyper-V' -Skip:$($IsLinux -or $IsMacOS) {
        It 'Hyper-V Module installed' {
            Get-Module -Name Hyper-V -ListAvailable | Should -Not -BeNullOrEmpty
        }

        It 'System is a Hypervisor' {
            Get-VMHost -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'ISO files are in <LabSourcesLocation>' -TestCases $winLabsources {
            (Get-ChildItem -Path $LabSourcesLocation -Filter *.iso -ErrorAction SilentlyContinue).Count | Should -BeGreaterThan 0
        }
    }

    Context 'Azure' {
        It 'Azure-module should be installed' {
            Get-InstalledModule -Name Az -MinimumVersion 4.8.0 -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'An Azure context should be available' {
            Get-AzContext -ErrorAction SilentlyContinue
        }
    }

    Context 'LibVirt (kvm/qemu/xen)' -Skip:$($IsWindows) {
        It 'System is a Hypervisor' {
            Get-Content -Path /proc/cpuinfo | Select-String -Pattern '^flags.*(vmx|svm)' | Should -Not -BeNullOrEmpty
        }

        It '<Package> is available' -TestCases $linuxRequiredTools {
            Get-Command -Name $Package -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Nested virtualization is enabled' {
            (Get-Content -Path /etc/modprobe.d/kvm.conf) -match '^options\s+kvm_(intel|amd)\s+nested=1' | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Role-specific' {

    }
}