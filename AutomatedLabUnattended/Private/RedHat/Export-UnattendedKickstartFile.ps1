function Export-UnattendedKickstartFile
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $idx = $script:un.IndexOf('%post')

    if ($idx -eq -1)
    {
        $script:un.Add('%post')
        $idx = $script:un.IndexOf('%post')
    }

    @(
        'if egrep --quiet "(RedHat|CentOS|Fedora)" /etc/os-release'
        'then'
        '  curl https://packages.microsoft.com/config/rhel/7/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo'
        '  yum install -y openssl'
        '  yum install -y powershell'
        '  yum install -y omi-psrp-server; fi'
        'elif egrep --quiet "Ubuntu" /etc/os-release'
        'then'
        '  wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb'
        '  dpkg -i packages-microsoft-prod.deb'
        '  apt-get update'
        '  add-apt-repository universe'
        '  apt-get install -y powershell'
        'fi'
    ) | ForEach-Object -Process {
        $idx++
        $script:un.Insert($idx, $_)
    }

    # When index of end is greater then index of package end: add %end to EOF
    # else add %end before %packages

    $idxPackage = $script:un.IndexOf('%packages --ignoremissing')
    $idxPost = $script:un.IndexOf('%post')

    $idxEnd = if (-1 -ne $idxPackage -and $idxPost -lt $idxPackage)
    {
        $idxPackage
    }
    else
    {
        $script:un.Count
    }

    $script:un.Insert($idxEnd, '%end')

    ($script:un | Out-String) -replace "`r`n", "`n" | Set-Content -Path $Path -Force
}
