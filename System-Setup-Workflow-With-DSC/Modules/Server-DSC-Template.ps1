param( 
    [string] $NodeId
)

Configuration ServerSetup {
    node $NodeId {

        Environment SCRIPTSHOME
        {
            Ensure = "Present"  
            Name = "SCRIPTS_HOME"
            Value = "D:\Scripts"
        }

        File LogDirectory
        {
            Ensure = "Present" 
            Type = "Directory"
            DestinationPath = "D:\Logs"    
        } 

        File DeployDirectory
        {
            Ensure = "Present" 
            Type = "Directory"
            DestinationPath = "D:\Deploy"    
        }

        File ScriptsDirectoryCopy
        {
            Ensure = "Present" 
            Type = "Directory" 
            Recurse = $true 
            SourcePath = "\\nas\app-ops\SharePoint-Scripts\"
            DestinationPath = "D:\Scripts"    
        }

        File UtilsDirectoryCopy
        {
            Ensure = "Present" 
            Type = "Directory" 
            Recurse = $true 
            SourcePath = "\\nas\app-ops\SharePoint-Utils\"
            DestinationPath = "D:\Utils"    
        }
    }
}