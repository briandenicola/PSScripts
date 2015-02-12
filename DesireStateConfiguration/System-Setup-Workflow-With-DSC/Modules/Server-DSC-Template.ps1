param( 
    [string] $NodeId
)

Configuration ServerSetup {
    node $NodeId {

        Environment SCRIPTSHOME
        {
            Ensure = "Present"  
            Name = "SCRIPTS_HOME"
            Value =  Join-Path -Path $env:SystemDrive -ChildPath "Scripts"
        }

        File TempDirectory
        {
            Ensure = "Present" 
            Type = "Directory"
            DestinationPath = Join-Path -Path $env:SystemDrive -ChildPath "Temp"  
        } 
    }
}