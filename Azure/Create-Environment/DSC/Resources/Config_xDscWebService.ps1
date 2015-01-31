configuration Config_xDscWebService {
    param (
        [string] $NodeName = 'localhost',
        [string] $SystemTimeZone = "Central Standard Time"
    )

    Import-DSCResource -ModuleName xPSDesiredStateConfiguration
    Import-DSCResource -ModuleName xTimeZone
    Import-DSCResource -ModuleName xCredSSP

    Node $NodeName
    {
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

        xTimeZone SetTimeZone 
        {
            TimeZone = $SystemTimeZone
        }

        xCredSSP Server 
        { 
            Ensure = "Present" 
            Role = "Server" 
        } 

        xCredSSP Client 
        { 
            Ensure = "Present" 
            Role = "Client" 
            DelegateComputers = "*" 
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
    }
 }