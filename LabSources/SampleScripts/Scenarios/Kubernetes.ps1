$labName = 'Kubernetes'

New-LabDefinition -Name $labName -DefaultVirtualizationEngine HyperV
Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace 10.196.0.0/24
Add-LabVirtualNetworkDefinition -Name 'Default Switch' -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'Ethernet' }

$netAdapter = @()
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch $labName -Ipv4Address 10.196.0.1
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch 'Default Switch' -UseDhcp
Add-LabMachineDefinition -Name DC01 -Gateway 10.196.0.1 -IpAddress 10.196.0.2 -Memory 2GB -Network $labName -Roles RootDC,CARoot -DomainName contoso.com -OperatingSystem 'Windows Server 2022 Datacenter Evaluation'
Add-LabMachineDefinition -Name GW01 -Memory 2GB -NetworkAdapter $netAdapter -Roles Routing -DomainName contoso.com -OperatingSystem 'Windows Server 2022 Datacenter Evaluation'
Add-LabMachineDefinition -Name KC01 -Gateway 10.196.0.1 -IpAddress 10.196.0.3 -Notes @{KubernetesRole = "ControlPlane"} -Memory 4GB -Network $labName -DomainName contoso.com -OperatingSystem 'CentOS Stream 10' -SshPublicKeyPath ~/.ssh/id_ed25519.pub -SshPrivateKeyPath  ~/.ssh/id_ed25519
Add-LabMachineDefinition -Name KN01 -Gateway 10.196.0.1 -IpAddress 10.196.0.4 -Notes @{KubernetesRole = "Node"} -Memory 4GB -Network $labName -DomainName contoso.com -OperatingSystem 'CentOS Stream 10' -SshPublicKeyPath ~/.ssh/id_ed25519.pub -SshPrivateKeyPath  ~/.ssh/id_ed25519
Add-LabMachineDefinition -Name KN02 -Gateway 10.196.0.1 -IpAddress 10.196.0.5 -Notes @{KubernetesRole = "Node"} -Memory 4GB -Network $labName -DomainName contoso.com -OperatingSystem 'CentOS Stream 10' -SshPublicKeyPath ~/.ssh/id_ed25519.pub -SshPrivateKeyPath  ~/.ssh/id_ed25519
Install-Lab

Checkpoint-LabVM -ComputerName KC01,KN01,KN02 -SnapshotName BeforeKubeadm

$kubernetesVersion = '1.34'
$crioVersion = '1.34'
Invoke-LabCommand -UseLocalCredential -ComputerName KC01,KE01,KN01,KN02 -Variable (Get-Variable kubernetesVersion, crioversion) -ScriptBlock {
@"
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v$kubernetesVersion/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v$kubernetesVersion/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
"@ | Set-Content  /etc/yum.repos.d/kubernetes.repo

@"
[cri-o]
name=CRI-O
baseurl=https://download.opensuse.org/repositories/isv:/cri-o:/stable:/v$crioVersion/rpm/
enabled=1
gpgcheck=1
gpgkey=https://download.opensuse.org/repositories/isv:/cri-o:/stable:/v$crioVersion/rpm/repodata/repomd.xml.key
"@ | Set-Content /etc/yum.repos.d/cri-o.repo
    dnf install -y container-selinux
    dnf install -y cri-o kubelet kubeadm kubectl --setopt=disable_excludes=kubernetes
    systemctl enable --now kubelet
    systemctl enable --now crio.service
    'net.ipv4.ip_forward=1' | Add-COntent /etc/sysctl.conf
    sysctl -p
} -PassThru

# Control Plane first
Invoke-LabCommand -ComputerName KC01 -ScriptBlock {
    kubeadm init

    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.0/manifests/tigera-operator.yaml
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.0/manifests/custom-resources.yaml
}
return
Invoke-LabCommand -UseLocalCredential -ComputerName KC01,KE01,KN01,KN02 -Variable (Get-Variable kubernetesVersion, crioversion) -ScriptBlock {
if (-not (Test-Path ~/AL)) {
$null = New-Item -ItemType Directory -Path ~/AL
}
@"
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta4
kubernetesVersion: v1.21.0
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
"@ | Set-Content ~/AL/k8s_cgroup.yml
    dnf install -y container-selinux
    dnf install -y cri-o kubelet kubeadm kubectl
    systemctl enable --now kubelet
} -PassThru
