param( 
    [string] $NodeName = 'localhost'
)

Configuration IISInstall {

    Node $NodeName
    {

        foreach($feature in @(
            "Web-Server", "Web-Default-Doc", "Web-ASP-Net", "Web-ASP-Net45", "Web-Log-Libraries", "Web-Basic-Auth","Web-Windows-Auth","Web-Http-Tracing",
            "Web-Request-Monitor", "Web-Mgmt-Tools","Web-Scripting-Tools","Web-Mgmt-Service","Web-Mgmt-Compat") )
        {
            WindowsFeature $feature
            {
                Ensure = 'Present'
                Name   = $feature
            }

        }
    }
}