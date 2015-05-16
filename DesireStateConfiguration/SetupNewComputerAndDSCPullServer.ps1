$ConfigurationData = @{
	AllNodes = @(
		@{
			NodeName = "*"
		    PSDscAllowPlainTextPassword = $true
		}
		@{
			NodeName = "localhost"
		}
	)
}

configuration DSCComputerSetup
{
    param(
        [Parameter(Mandatory=$false)][String] $SystemTimeZone = "Central Time Zone"
    )

    Import-DSCResource -ModuleName xPSDesiredStateConfiguration
    Import-DSCResource -ModuleName xTimeZone
    Import-DSCResource -ModuleName xCredSSP
    Import-DSCResource -ModuleName xSmbShare
    Import-DSCResource -ModuleName xNetworking
    Import-DSCResource -ModuleName xPendingReboot
    Import-DSCResource -ModuleName xActiveDirectory
    Import-DSCResource -ModuleName xComputerManagement 
    Import-DSCResource -ModuleName xRemoteDesktopAdmin
    Import-DSCResource -ModuleName xPowerShellExecutionPolicy

    Node 'localhost'
    {
        LocalConfigurationManager 
        { 
            RebootNodeIfNeeded = 'True' 
        }

        Environment SCRIPTS_HOME
        {
            Ensure         = "Present"
            Name           = "SCRIPTS_HOME"
            Value          = (Join-Path -Path $env:systemdrive -ChildPath "Scripts")
        }

        File DataFolder
        {
            Ensure          = "Present"
            DestinationPath = (Join-Path -Path $env:systemdrive -ChildPath "Data")
            Type            = "Directory"
        }

        File ScriptsFolder
        {
            Ensure          = "Present"
            SourcePath      = (Join-Path -Path $env:systemdrive -ChildPath "Data\Scripts")
            DestinationPath = (Join-Path -Path $env:systemdrive -ChildPath "Scripts")
            Type            = "Directory"
        }

        File UtilsFolder
        {
            Ensure          = "Present"
            DestinationPath = (Join-Path -Path $env:systemdrive -ChildPath "Utils")
            Type            = "Directory"
        }

        xSmbShare DataShare
        {
            Ensure = "Present"
            Name   = "Data"
            Path   = (Join-Path -Path $env:systemdrive -ChildPath "Data")
        }

        xTimeZone SetTimeZone 
        {
            TimeZone = $SystemTimeZone
        }

        xCredSSP Server 
        { 
            Ensure = "Present" 
            Role   = "Server" 
        } 

        xCredSSP Client 
        { 
            Ensure            = "Present" 
            Role              = "Client" 
            DelegateComputers = "*" 
        }

        WindowsFeature DSCServiceFeature
        {
            Ensure = "Present"
            Name   = "DSC-Service"            
        }

        WindowsFeature WebMgmtConsole
        {
            Ensure = "Present"
            Name   = "Web-Mgmt-Console"            
        }

        WindowsFeature WebMgmtTools
        {
            Ensure = "Present"
            Name   = "Web-Mgmt-Tools"            
        }

        WindowsFeature WebScriptingTools
        {
            Ensure = "Present"
            Name   = "Web-Scripting-Tools"            
        }      

        xDscWebService PSDSCPullServer
        {
            Ensure                  = "Present"
            EndpointName            = "PSDSCPullServer"
            Port                    = 80
            PhysicalPath            = "$env:SystemDrive\inetpub\wwwroot\PSDSCPullServer"
            CertificateThumbPrint   = "AllowUnencryptedTraffic"        
            ModulePath              = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules"
            ConfigurationPath       = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration"            
            State                   = "Started"
            DependsOn               = "[WindowsFeature]DSCServiceFeature"                        
        }

        xDscWebService PSDSCComplianceServer
        {
            Ensure                  = "Present"
            EndpointName            = "PSDSCComplianceServer"
            Port                    = 81
            PhysicalPath            = "$env:SystemDrive\inetpub\wwwroot\PSDSCComplianceServer"
            CertificateThumbPrint   = "AllowUnencryptedTraffic"
            State                   = "Started"
            IsComplianceServer      = $true
            DependsOn               = @("[WindowsFeature]DSCServiceFeature","[xDSCWebService]PSDSCPullServer")
        }

        xRemoteDesktopAdmin RemoteDesktopSettings
        {
           Ensure = 'Present'
           UserAuthentication = 'Secure'
        }

        xFirewall AllowRDP
        {
            Name = 'DSC - Remote Desktop Admin Connections'
            DisplayGroup = "Remote Desktop"
            Ensure = 'Present'
            State = 'Enabled'
            Access = 'Allow'
            Profile = 'Domain'
        }
    }
}