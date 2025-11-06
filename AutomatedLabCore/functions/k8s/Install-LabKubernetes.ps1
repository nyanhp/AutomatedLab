function Install-LabKubernetes {
    [CmdletBinding()]
    param ()

    <#
    Role properties:
    - Control Plane Node
    - Pod Count Max (?)
    - Limits (?)
    - Network
    - Helm reference
    - Node pools
    - etcd, coredns auf separaten nodes
    - invoke-labkubectl (?)
    - install-labkubecredential (?)
    #>

    Write-PSFMessage "Retrieving Kubernetes role machines..."
    $machines = Get-LabVM -Role Kubernetes
    if (-not $machines) {
        Write-Warning "No machines with the 'Kubernetes' role found. Exiting."
        return
    }

    foreach ($machine in $machines) {
        $roleParams = $machine.Role | Where-Object { $_.Name -eq 'Kubernetes' } | Select-Object -ExpandProperty Properties -ErrorAction SilentlyContinue
        Write-PSFMessage "Installing Kubernetes on $($machine.Name) ($($machine.OperatingSystem))..."
        
        switch ($machine.OperatingSystem) {
            '*Windows*' {
                Invoke-LabCommand -ComputerName $machine.Name -ActivityName 'Install Kubernetes' -ScriptBlock {
                    if (-not (Get-Command kubeadm -ErrorAction SilentlyContinue)) {
                        Write-PSFMessage 'Installing Kubernetes tools (kubeadm, kubelet, kubectl) via Chocolatey...'
                        if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
                            Set-ExecutionPolicy Bypass -Scope Process -Force
                            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                            iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
                        }
                        choco install -y kubernetes-cli
                    }
                    Write-PSFMessage 'Initializing Kubernetes cluster with kubeadm...'
                    kubeadm init --pod-network-cidr=10.244.0.0/16
                } -AsJob
            }
            '*Red Hat*' {
                Invoke-LabCommand -ComputerName $machine.Name -ActivityName 'Install Kubernetes' -ScriptBlock {
                    sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
                    sudo systemctl enable --now kubelet
                    sudo kubeadm init --pod-network-cidr=10.244.0.0/16
                } -AsJob
            }
            '*SUSE*' {
                Invoke-LabCommand -ComputerName $machine.Name -ActivityName 'Install Kubernetes' -ScriptBlock {
                    sudo zypper refresh
                    sudo zypper install -y kubeadm kubelet kubectl
                    sudo systemctl enable --now kubelet
                    sudo kubeadm init --pod-network-cidr=10.244.0.0/16
                } -AsJob
            }
            default {
                Write-Warning "Unsupported OS: $($machine.OperatingSystem) on $($machine.Name). Skipping."
            }
        }
    }
    Write-PSFMessage "Kubernetes installation jobs submitted. Monitor job status for completion."
}
