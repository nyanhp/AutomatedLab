Configuration "$($env:COMPUTERNAME)"
{
    Import-DscResource –ModuleName 'PSDesiredStateConfiguration'

    Node localhost
    {
        File "TestFile$($env:COMPUTERNAME)"
        {
            Ensure = 'Present'
            Type = 'File'
            DestinationPath = "C:\DscTestFile_$($env:COMPUTERNAME)"
            Contents = 'OK'
        }
    }
}

&"$($env:COMPUTERNAME)" -OutputPath C:\DscTestConfig | Out-Null
Rename-Item -Path C:\DscTestConfig\localhost.mof -NewName "$($env:COMPUTERNAME).mof"