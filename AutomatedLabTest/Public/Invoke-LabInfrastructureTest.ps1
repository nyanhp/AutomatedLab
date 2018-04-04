function Invoke-LabInfrastructureTest
{
    [CmdletBinding()]
    param ( )

    $lab = Get-Lab -ErrorAction SilentlyContinue
    if (-not $lab)
    {
        Write-Warning -Message "No lab imported - nothing to test"
        return
    }

    if ((Get-Module Pester -ListAvailable | Sort-Object -Property Version | Select-Object -Last 1).Version -lt 4.0.0)
    {
        Write-Warning -Message "Pester is not available with v4 or greater. Skipping tests."
        return
    }
    # Test definition pattern: Invoke-HYPERVISORRoleROLENAMETest (e.g. Invoke-HyperVRootDCTest) for all role-specific tests, Generic test: Invoke-LabDeploymentTest

    $deploymentCommand = "Invoke-$($lab.DefaultVirtualizationEngine)LabDeploymentTest"
    & $deploymentCommand

    foreach ( $testScript in (Get-Command -Name "Invoke-$($Lab.DefaultVirtualizationEngine)Role*Test"))
    {
        & $testScript
    }
}
