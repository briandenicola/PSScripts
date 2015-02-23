Configuration IIS85WebServerSetup
{
    param (
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$NodeName
    )

    Node $NodeName
    {
        WindowsFeature WebServerFeature
        {
            Name = "Web-Server"
            Ensure = "Present"
        }

        WindowsFeature WebAspNetFeature
        {
            Name = "Web-ASP-NET"
            Ensure = "Present"
        }

        WindowsFeature WebNetExtFeature
        {
            Name = "Web-Net-Ext"
            Ensure = "Present"
        }

        WindowsFeature WebISAPIFeature
        {
            Name = "Web-ISAPI-Ext"
            Ensure = "Present"
        }

        WindowsFeature WebISAPIFilterFeature
        {
            Name = "Web-ISAPI-Filter"
            Ensure = "Present"
        }

        WindowsFeature WebHttpLoggingFeature
        {
            Name = "Web-Http-Logging"
            Ensure = "Present"
        }

        WindowsFeature WebHttpLogLibrariesFeature
        {
            Name = "Web-Log-Libraries"
            Ensure = "Present"
        }

        WindowsFeature WebRequestMonitorFeature
        {
            Name = "Web-Request-Monitor"
            Ensure = "Present"
        }

        WindowsFeature WebHttpTracingFeature
        {
            Name = "Web-Http-Tracing"
            Ensure = "Present"
        }

        WindowsFeature WebCustomLoggingFeature
        {
            Name = "Web-Custom-Logging"
            Ensure = "Present"
        }

        WindowsFeature WebBasicAuthFeature
        {
            Name = "Web-Basic-Auth"
            Ensure = "Present"
        }

        WindowsFeature WebWindowsAuthFeature
        {
            Name = "Web-Windows-Auth"
            Ensure = "Present"
        }

        WindowsFeature WebDigestAuthFeature
        {
            Name = "Web-Digest-Auth"
            Ensure = "Present"
        }

        WindowsFeature WebDynCompressionFeature
        {
            Name = "Web-Dyn-Compression"
            Ensure = "Present"
        }

        WindowsFeature WebMgmtToolsFeature
        {
            Name = "Web-Mgmt-Tools"
            Ensure = "Present"
        }

        WindowsFeature WebMgmtConsoleFeature
        {
            Name = "Web-Mgmt-Console"
            Ensure = "Present"
        }

        WindowsFeature WebMetabaseFeature
        {
            Name = "Web-Metabase"
            Ensure = "Present"
        }

        WindowsFeature WebWMIFeature
        {
            Name = "Web-WMI"
            Ensure = "Present"
        }

        WindowsFeature WebScriptingToolsFeature
        {
            Name = "Web-Scripting-Tools"
            Ensure = "Present"
        }

        WindowsFeature WebLegacyFeature
        {
            Name = "Web-Lgcy-Scripting"
            Ensure = "Present"
        }

        WindowsFeature WebAspNet45Feature
        {
            Name = "Web-Asp-Net45"
            Ensure = "Present"
        }

        WindowsFeature WebAspNet45ExtFeature
        {
            Name = "Web-Net-Ext45"
            Ensure = "Present"
        }

        WindowsFeature WebAppInitFeature
        {
            Name = "Web-AppInit"
            Ensure = "Present"
        }

        WindowsFeature WebHttpRedirectFeature
        {
            Name = "Web-Http-Redirect"
            Ensure = "Present"
        }

        WindowsFeature WebMgmtServiceFeature
        {
            Name = "Web-Mgmt-Service"
            Ensure = "Present"
        }
    }
}