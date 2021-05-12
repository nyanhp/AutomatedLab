# Test structure

## General tests

### Get-LabConfigurationItem.tests.ps1

Test all calls to Get-LabConfigurationItem to ensure that there actually *is* a configuration item

## Lab functionality

These tests should deploy different roles and combinations of roles to ensure that AL is 
still working as it should. For the time being we simply deploy the DSC workshop lab without 
added customizations. Invoke-LabPester is executed after the lab has finished to generate test results.

This way we offload most of the testing to our AutomatedLabTest module, which is used for
more than just deployment testing.

### Azure.tests.ps1

Test deployments on Azure

### Hyperv.tests.ps1

Test deployments on HyperV