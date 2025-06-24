@{
    TemplateName         = 'AutomatedLabCustomRole'
    Version              = "1.0.0.0"
    AutoIncrementVersion = $true
    Tags                 = 'automatedlab', 'file', 'customrole'
    Author               = 'AutomatedLab Team'
    Description          = 'A Custom Role for AutomatedLab'
    Exclusions           = @("PSMDInvoke.ps1", ".PSMDDependency") # Contains list of files - relative path to root - to ignore when building the template
    Scripts              = @{ }
}