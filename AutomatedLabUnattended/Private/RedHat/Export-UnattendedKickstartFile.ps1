function Export-UnattendedKickstartFile
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $idx = $script:un.IndexOf('%post --log=/var/log/automatedlab_ks_post.log')

    if ($idx -eq -1)
    {
        $script:un.Add('%post --log=/var/log/automatedlab_ks_post.log')
        $idx = $script:un.IndexOf('%post --log=/var/log/automatedlab_ks_post.log')
    }

    if ($script:un[$idx + 1] -ne 'date')
    {
        $content = @('date')

        if ($script:un | Where-Object {$_ -like 'network --bootproto=dhcp*' -and $_ -notlike '*--gateway*'})
        {
            $gwIp = (Get-NetIPAddress -InterfaceAlias 'vEthernet (Default Switch)' -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPv4Address
            $content += 'echo "search mshome.net" > /etc/resolv.conf'
            $content += 'echo "nameserver {0}" >> /etc/resolv.conf' -f $gwIp
        }

        $content += @(            
            'curl https://packages.microsoft.com/config/rhel/7/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo'
            'yum install -y openssl'
            'yum install -y omi'
            'yum install -y powershell'
            'yum install -y omi-psrp-server'
            'yum list installed "powershell" > /tmp/ksPowerShell'
            'yum list installed "omi-psrp-server" > /tmp/ksOmi'
            'authselect sssd with-mkhomedir'
            'echo "Subsystem powershell /usr/bin/pwsh -sshs -NoLogo" >> /etc/ssh/sshd_config'
        )
        
        $content | ForEach-Object -Process {
            $idx++
            $script:un.Insert($idx, $_)
        }

        # When index of end is greater then index of package end: add %end to EOF
        # else add %end before %packages

        $idxPackage = $script:un.IndexOf('%packages --ignoremissing')
        $idxPost = $script:un.IndexOf('%post --log=/var/log/automatedlab_ks_post.log')

        $idxEnd = if (-1 -ne $idxPackage -and $idxPost -lt $idxPackage)
        {
            $idxPackage
        }
        else
        {
            $script:un.Count
        }

        $script:un.Insert($idxEnd, '%end')
    }

    ($script:un | Out-String) -replace "`r`n", "`n" | Set-Content -Path $Path -Force
}
