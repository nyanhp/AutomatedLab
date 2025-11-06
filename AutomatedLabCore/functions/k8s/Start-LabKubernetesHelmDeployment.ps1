function Start-LabKubernetesHelmDeployment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$HelmChartName,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$ReleaseName = 'default-release',

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Namespace = 'default'
    )

    $vms = Get-LabVM -Role Kubernetes
}