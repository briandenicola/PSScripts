param( 
    [string] $NodeId
)

Configuration IISServerSetup {
    node $NodeId {

        Group GroupExample 
        {
            GroupName = "Administrators"
            Members = "SharePoint-Ops"
        }

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

        xSmbShare LogShare 
        { 
          Ensure = "Present"  
          Name   = "Logs" 
          Path =  "D:\Logs"          
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

        InstallIIS CustomIISInstall 
        {
            Ensure = "Present"    
        }
    }
}
#IISServerSetup 