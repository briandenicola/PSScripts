Set-Variable -Name check_service_application_status -Value ( [ScriptBlock]  {
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
	Get-SPServiceApplication | 
     Select DisplayName, IisVirtualDirectoryPath, @{Name="AppPoolName";Expression={$_.ApplicationPool.Name}}, @{Name="AppPoolUser";Expression={$_.ApplicationPool.ProcessAccountName}}
})

Set-Variable -Name check_service_instance_status -Value ( [ScriptBlock]  {
	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
	Get-SPStartedServices
})