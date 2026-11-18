function Install-LabKubernetes {
    [CmdletBinding()]
    param ()

    # Kudos to https://github.com/kelseyhightower/kubernetes-the-hard-way for a proper bootstrapping

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

    $caConfTemplate = @'
[req]
distinguished_name = req_distinguished_name
prompt             = no
x509_extensions    = ca_x509_extensions

[ca_x509_extensions]
basicConstraints = CA:TRUE
keyUsage         = cRLSign, keyCertSign

[req_distinguished_name]
C   = US
ST  = Washington
L   = Seattle
CN  = CA

[admin]
distinguished_name = admin_distinguished_name
prompt             = no
req_extensions     = default_req_extensions

[admin_distinguished_name]
CN = admin
O  = system:masters

# Service Accounts
#
# The Kubernetes Controller Manager leverages a key pair to generate
# and sign service account tokens as described in the
# [managing service accounts](https://kubernetes.io/docs/admin/service-accounts-admin/)
# documentation.

[service-accounts]
distinguished_name = service-accounts_distinguished_name
prompt             = no
req_extensions     = default_req_extensions

[service-accounts_distinguished_name]
CN = service-accounts

# Kube Proxy Section
[kube-proxy]
distinguished_name = kube-proxy_distinguished_name
prompt             = no
req_extensions     = kube-proxy_req_extensions

[kube-proxy_req_extensions]
basicConstraints     = CA:FALSE
extendedKeyUsage     = clientAuth, serverAuth
keyUsage             = critical, digitalSignature, keyEncipherment
nsCertType           = client
nsComment            = "Kube Proxy Certificate"
subjectAltName       = DNS:kube-proxy, IP:127.0.0.1
subjectKeyIdentifier = hash

[kube-proxy_distinguished_name]
CN = system:kube-proxy
O  = system:node-proxier
C  = US
ST = Washington
L  = Seattle


# Controller Manager
[kube-controller-manager]
distinguished_name = kube-controller-manager_distinguished_name
prompt             = no
req_extensions     = kube-controller-manager_req_extensions

[kube-controller-manager_req_extensions]
basicConstraints     = CA:FALSE
extendedKeyUsage     = clientAuth, serverAuth
keyUsage             = critical, digitalSignature, keyEncipherment
nsCertType           = client
nsComment            = "Kube Controller Manager Certificate"
subjectAltName       = DNS:kube-controller-manager, IP:127.0.0.1
subjectKeyIdentifier = hash

[kube-controller-manager_distinguished_name]
CN = system:kube-controller-manager
O  = system:kube-controller-manager
C  = US
ST = Washington
L  = Seattle


# Scheduler
[kube-scheduler]
distinguished_name = kube-scheduler_distinguished_name
prompt             = no
req_extensions     = kube-scheduler_req_extensions

[kube-scheduler_req_extensions]
basicConstraints     = CA:FALSE
extendedKeyUsage     = clientAuth, serverAuth
keyUsage             = critical, digitalSignature, keyEncipherment
nsCertType           = client
nsComment            = "Kube Scheduler Certificate"
subjectAltName       = DNS:kube-scheduler, IP:127.0.0.1
subjectKeyIdentifier = hash

[kube-scheduler_distinguished_name]
CN = system:kube-scheduler
O  = system:system:kube-scheduler
C  = US
ST = Washington
L  = Seattle

[default_req_extensions]
basicConstraints     = CA:FALSE
extendedKeyUsage     = clientAuth
keyUsage             = critical, digitalSignature, keyEncipherment
nsCertType           = client
nsComment            = "Admin Client Certificate"
subjectKeyIdentifier = hash
'@

    $caConfApiTemplate = @'
[kube-api-server]
distinguished_name = kube-api-server_distinguished_name
prompt             = no
req_extensions     = kube-api-server_req_extensions

[kube-api-server_req_extensions]
basicConstraints     = CA:FALSE
extendedKeyUsage     = clientAuth, serverAuth
keyUsage             = critical, digitalSignature, keyEncipherment
nsCertType           = client, server
nsComment            = "Kube API Server Certificate"
subjectAltName       = @kube-api-server_alt_names
subjectKeyIdentifier = hash

[kube-api-server_alt_names]
IP.0  = 127.0.0.1
SERVERIP
DNS.0 = kubernetes
DNS.1 = kubernetes.default
DNS.2 = kubernetes.default.svc
DNS.3 = kubernetes.default.svc.cluster
DNS.4 = kubernetes.svc.cluster.local
DNS.5 = server.kubernetes.local
DNS.6 = api-server.kubernetes.local

[kube-api-server_distinguished_name]
CN = kubernetes
C  = US
ST = Washington
L  = Seattle
'@

    $caConfWorkerTemplate = @'
[WORKERNODENAME]
distinguished_name = WORKERNODENAME_distinguished_name
prompt             = no
req_extensions     = WORKERNODENAME_req_extensions

[WORKERNODENAME_req_extensions]
basicConstraints     = CA:FALSE
extendedKeyUsage     = clientAuth, serverAuth
keyUsage             = critical, digitalSignature, keyEncipherment
nsCertType           = client
nsComment            = "WORKERNODENAME Certificate"
subjectAltName       = DNS:WORKERNODENAME, DNS:WORKERNODEFQDN, IP:127.0.0.1
subjectKeyIdentifier = hash

[WORKERNODENAME_distinguished_name]
CN = system:node:WORKERNODENAME
O  = system:nodes
C  = US
ST = Washington
L  = Seattle
'@

    Write-ScreenInfo "Retrieving Kubernetes role machines..."
    $machines = Get-LabVM -Role Kubernetes -IncludeLinux
    if (-not $machines) {
        Write-Warning "No machines with the 'Kubernetes' role found. Exiting."
        return
    }

    $versions = $machines | Foreach-Object {
        $v = ($_.Roles | Where-Object Name -eq 'Kubernetes').Properties['Version']
        if ($v) { $v } else { "1.37.2" }
    } | Sort-Object -Unique

    # Bootstrap stuff once
    foreach ($kubernetesVersion in $versions) {
        [version]$versionFull = $kubernetesVersion
        $versionMajorMinor = '{0}.{1}.0' -f $versionFull.Major, $versionFull.Minor
        foreach ($entry in (Get-LabConfigurationItem -Name KubernetesComponentUrls).GetEnumerator()) {
            $destination = "$labSources/SoftwarePackages/Kubernetes/$($kubernetesVersion)/"
            $null = New-Item -ItemType Directory -Path $destination -Force -ErrorAction SilentlyContinue
            $theFile = Get-LabInternetFile -Uri $entry.Value.Replace('KUBEVERSION_MAJORMINOR', $versionMajorMinor.ToString()).Replace('KUBEVERSION', $versionFull.ToString()) -Path $destination -PassThru
            Copy-LabFileItem -ComputerName $machines -Path $theFile.FullName -DestinationFolderPath '/usr/bin'
        }

        foreach ($entry in (Get-LabConfigurationItem -Name KubernetesVersionedComponentUrls).GetEnumerator()) {
            [version]$versionFull = $kubernetesVersion
            $versionMajorMinor = '{0}.{1}.0' -f $versionFull.Major, $versionFull.Minor
            $destination = "$labSources/SoftwarePackages/Kubernetes/$($kubernetesVersion)/"
            $null = New-Item -ItemType Directory -Path $destination -Force -ErrorAction SilentlyContinue
            $theFile = Get-LabInternetFile -Uri $entry.Value.Uri -Path $destination -PassThru
            if ($entry.Value.Decompress) {
                Expand-Archive -Path $theFile.FullName -DestinationPath $destination -Force
            }
        }
    }

    $groups = $machines | Group-Object { ($_.Roles| Where-Object Name -eq 'Kubernetes').Properties['NodeRole'] } -AsHashTable -AsString

    Write-ScreenInfo "Copying files to nodes"
    downloads/controller/kube-apiserver \
    downloads/controller/kube-controller-manager \
    downloads/controller/kube-scheduler \
    downloads/client/kubectl

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
    Invoke-LabCommand -ComputerName $groups['Worker'] -ScriptBlock { 
        $null = New-Item -ItemType Directory -Path /var/lib/kubelet/ 
    }
    foreach ($worker in $groups['Worker']) {
        # TODO Request-LabCert muss auch Linux Cert schreiben
        Request-LabCertificate -Subject $worker.Fqdn, $worker.IpV4Address -SAN $worker.Name, $worker. -OnlineCA (Get-LabIssuingCA) -ComputerName $worker.Name
    } -NoDisplay

    Invoke-LabCommand -ComputerName $machines -ScriptBlock {
        if (Get-Command dnf -ErrorAction SilentlyContinue) {
            sudo dnf install -y nfs-utils libnfsidmap sssd-nfs-idmap socat conntrack ipset kmod
        }
        elseif (Get-Command apt-get -ErrorAction SilentlyContinue) {
            sudo apt-get install -y nfs-kernel-server nfs-common socat conntrack ipset kmod
        }
        elseif (Get-Command zypper) {
            sudo zypper in nfs-kernel-server nfs-common socat conntrack ipset kmod
        }
    } -NoDisplay

    foreach ($machine in $groups['ControlPlane']) {
        $roleParams = ($machine.Roles | Where-Object Name -eq 'Kubernetes').Properties
        $kubernetesVersion = ($_.Roles | Where-Object Name -eq 'Kubernetes').Properties['Version']
        if ($kubernetesVersion) { $kubernetesVersion } else { "1.37.2" }
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

        Write-ScreenInfo "Boostrapping etcd"
        Copy-LabFileItem -ComputerName $machine -Path "$labSources/SoftwarePackages/Kubernetes/$($kubernetesVersion)/etcd", "$labSources/SoftwarePackages/Kubernetes/$($kubernetesVersion)/etcdctl" -DestinationFolderPath /usr/local/bin/
        
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
