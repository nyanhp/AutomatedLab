function Install-LabKubernetes {
    [CmdletBinding()]
    param ()

    <#
    Considerations:
    - Simple Cluster without thousand lab role requirements
      - First node shares NFS mount to other nodes (instead of file server cluster nfs)
      - Cluster uses cacert file, even if LabCA is available (shortcomings of request-labcertificate, as k8s needs to sign certs, acting as an intermediary)
    - Networking, Storage, Container Runtime uses simple defaults containerd, nfs, bridge-networking

    Future improvements:
    - Custom csi, cni, cri, prepared already with install snippets
    - Custom Storage Classes? LimitRanges?
    - MetalLB load balancer class?

    Version     = '[string] Version to use, defaults to 1.37.2'
    ClusterName = '[string] Name of the cluster. Defaults to "kubernetes"'
    NodeRole    = '[string] Node role. Either ControlPlane or Worker. Might be extended for future use such as etcd, ...'
    CriType     = '[string] Container Runtime Interface, currently only containerd is supported'
    CniType     = '[string] Cluster Network Interface, currently only Bridge is supported'
    CsiType     = '[string] Cluster Storage Interface, currently only SMB is supported'
    #>

    Write-ScreenInfo "Retrieving Kubernetes role machines..."
    $machines = Get-LabVM -Role Kubernetes
    if (-not $machines) {
        Write-Warning "No machines with the 'Kubernetes' role found. Exiting."
        return
    }

    $versions = $machines | Foreach-Object {
        $v = ($_.Role | Where-Object Name -eq 'Kubernetes').Properties['Version']
        if ($v) { $v } else { "1.37.2" }
    } | Sort-Object -Unique

    # Bootstrap stuff once
    foreach ($kubernetesVersion in $versions) {
        foreach ($entry in (Get-LabConfigurationItem -Name KubernetesComponentUrls).GetEnumerator()) {
            [version]$versionFull = $kubernetesVersion
            $versionMajorMinor = '{0}.{1}.0' -f $versionFull.Major, $versionFull.Minor
            $destination = "$labSources/SoftwarePackages/Kubernetes/$($kubernetesVersion)/"
            $null = New-Item -ItemType Directory -Path $destination -Force -ErrorAction SilentlyContinue
            Get-LabInternetFile -Uri $entry.Value.Replace('KUBEVERSION', $versionFull.ToString()).Replace('KUBEVERSION_MAJORMINOR', $versionMajorMinor.ToString()) -Path $destination
        }
    }

    $groups = $machines | Group-Object { ($_.Roles| Where-Object Name -eq 'Kubernetes').Properties['NodeRole'] } -AsHashTable -AsString

    Write-ScreenInfo "Provisioning Certificates"
    # TODO openssl wenn keine CA
    foreach ($cert in @(
            "admin"
            "kube-proxy"
            "kube-scheduler"
            "kube-controller-manager"
            "kube-api-server"
            "service-accounts"
        ) ) {
        Request-LabCertificate -Subject $cert -OnlineCA (Get-LabIssuingCA) -ComputerName $groups['ControlPlane'].Name
    }

    Write-ScreenInfo "Provisioning Worker NodeCertificates"
    Invoke-LabCommand -ComputerName $groups['Worker'] -ScriptBlock { $null = New-Item -ItemType Directory -Path /var/lib/kubelet/ }
    foreach ($worker in $groups['Worker']) {
        # TODO Request-LabCert muss auch Linux Cert schreiben
        Request-LabCertificate -Subject $worker.Fqdn, $worker.IpV4Address -SAN $worker.Name, $worker. -OnlineCA (Get-LabIssuingCA) -ComputerName $worker.Name
    } -NoDisplay

    Invoke-LabCommand -ComputerName $machines -ScriptBlock {
        if (Get-Command dnf -ErrorAction SilentlyContinue) {
            sudo dnf install -y nfs-utils libnfsidmap sssd-nfs-idmap
        }
        elseif (Get-Command apt-get -ErrorAction SilentlyContinue) {
            sudo apt-get install -y nfs-kernel-server nfs-common
        }
        elseif (Get-Command zypper) {
            sudo zypper in nfs-kernel-server nfs-common
        }
    } -NoDisplay

    foreach ($machine in $groups['ControlPlane']) {
        $roleParams = ($machine.Roles | Where-Object Name -eq 'Kubernetes').Properties
        $first = $groups['ControlPlane'][0]

        Write-ScreenInfo -Message "Sharing out NFS folder for Kubernetes cluster on $first"
        if ($machine.Name -eq $first.Name) {
            Invoke-LabCommand -ComputerName $first -ScriptBlock {
                if (Get-Command dnf -ErrorAction SilentlyContinue) {
                    sudo dnf install -y nfs-utils libnfsidmap sssd-nfs-idmap
                    firewall-cmd --permanent --add-service=nfs
                    firewall-cmd --reload
                    systemctl enable nfs-server --now
                }
                elseif (Get-Command apt-get -ErrorAction SilentlyContinue) {
                    sudo apt-get install -y nfs-kernel-server nfs-common
                    systemctl enable --now nfs-server.service
                }
                elseif (Get-Command zypper) {
                    sudo zypper in nfs-kernel-server nfs-common
                    systemctl enable --now nfs-server.service
                }

                mkdir /opt/clusterstorage
                Add-Content -Path /etc/exports -Value '/opt/clusterstorage/ *(rw,sync,no_root_squash,subtree_check)'
                sudo exportfs -ra
            } -NoDisplay
        }
        
        Write-ScreenInfo "Installing Kubernetes Control Plane"


        Write-ScreenInfo "Enabling NFS StorageClass"
        Invoke-LabCommand $machine {
            helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
            helm repo update
            helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --set nfs.server=$($first.Fqdn) --set nfs.path=/opt/clusterstorage
        } -Variable (Get-Variable first) -NoDisplay
        <#
        for host in node-0 node-1; do
  ssh root@${host} mkdir /var/lib/kubelet/

  scp ca.crt root@${host}:/var/lib/kubelet/

  scp ${host}.crt \
    root@${host}:/var/lib/kubelet/kubelet.crt

  scp ${host}.key \
    root@${host}:/var/lib/kubelet/kubelet.key
done

Copy the appropriate certificates and private keys to the server machine:

scp \
  ca.key ca.crt \
  kube-api-server.key kube-api-server.crt \
  service-accounts.key service-accounts.crt \
  root@server:~/
        #>
        
        
    }
    Write-ScreenInfo "Kubernetes installation jobs submitted. Monitor job status for completion."
}
