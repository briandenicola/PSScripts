[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[Parameter(Mandatory=$true)]
	[string[]] $computers,
	
	[Parameter(Mandatory=$true)]
	[string] $sql_server,
	
	[Parameter(Mandatory=$true)]
	[string] $admin_group,
	
	[Parameter(Mandatory=$true)]
	[string] $readers_group,
	
	[Parameter(Mandatory=$true)]
	[string] $users_group
)

Import-Module ApplicationServer


function Set-ServiceCredential([string]$serviceName, $credential, [string] $computer)
{
    $domainAndUserName = $credential.GetNetworkCredential().Domain + "\" + $credential.GetNetworkCredential().UserName;
    $service = Get-WmiObject Win32_Service -filter "name='$serviceName'" -ComputerName $computer
    $service.Change($null, $null, $null, $null, $null, $null, $domainAndUserName, $credential.GetNetworkCredential().Password) |out-null
    Restart-Service -name "$serviceName"
}

# Gets a SQL connection string to the specified server and database.
function Create-SqlConnString([string]$server, [string]$database)
{
    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder.PSBase.DataSource = $server
    $builder.PSBase.InitialCatalog = $database
    $builder.PSBase.IntegratedSecurity = $true
    return [string] $builder.ToString()
}

### Event Collector Service (ECS) and Workflow Management Service (WMS) service names.
$ECS_ServiceName = "AppFabricEventCollectionService"
$WMS_ServiceName = "AppFabricWorkflowManagementService"

### Monitoring database
$monitoring_database = "AppFabric_Monitoring_Store"
$monitoring_connection = Create-SqlConnString $sql_server $monitoring_database

### Persistence database
$persistence_database = "AppFabric_Persistence_Store"
$persistence_connection = Create-SqlConnString $sql_server $persistence_database

## Setup Databases
Initialize-ASMonitoringSqlDatabase  –Server $sql_server –Database $monitoring_database –Admins $admin_group –Readers $readers_group –Writers $users_group
Initialize-ASPersistenceSqlDatabase -Server $sql_server -Database $persistence_database -Admins $admin_group -Readers $readers_group -Users $users_group

###########################
### Collect credentials ###
###########################

$systemService_Credentials = Get-Credential
$systemService_Domain = $systemService_Credentials.GetNetworkCredential().Domain
$systemService_UserName = $systemService_Credentials.GetNetworkCredential().UserName

############################
### Update configuration ###
############################
$sb = {
	param (
		[string] $monitoring_connection,
		[string] $monitoring_database,
		[string] $persistence_connection,
		[string] $persistence_database
	)
	
	Import-Module ApplicationServer
	$appcmd = "$env:SystemRoot\system32\inetsrv\appcmd.exe"
	& $appcmd set config /clr:4 /commit:WEBROOT /section:connectionStrings /+"[connectionString='$monitoring_connection',name='$monitoring_database',providerName='System.Data.SqlClient']" |out-null
	& $appcmd set config /clr:4 /commit:WEBROOT /section:connectionStrings /+"[connectionString='$persistence_connection',name='$persistence_database',providerName='System.Data.SqlClient']" |out-null
	
	Add-ASAppSqlInstanceStore -Name "sqlPersistence" -ConnectionStringName $persistence_database -Root |out-null
	Set-ASAppMonitoring -ConnectionStringName $monitoring_database -MonitoringLevel "HealthMonitoring" -Root |out-null
	Set-ASAppSqlServicePersistence -ConnectionStringName $persistence_database -Root -HostLockRenewalPeriod "00:00:20" -InstanceEncodingOption "GZip" -InstanceCompletionAction "DeleteNothing" -InstanceLockedExceptionAction "BasicRetry" |out-null
}

foreach ( $computer in $computers )
{
	Write-Output "Adding the Administrator user to the local Administrators group on $computer"
	$oGroup = [ADSI]"WinNT://$computer/Administrators"
	trap { continue } #'Administrator user already a member of the local Administrators group...'; 
	& { $oGroup.Add("WinNT://$systemService_Domain/$systemService_UserName") }

	Write-Output "Updating Event Collection service on " $computer
	Set-ServiceCredential $ECS_ServiceName $systemService_Credentials $computer

	Write-Output "Updating Workflow Management service on " $computer
	Set-ServiceCredential $WMS_ServiceName $systemService_Credentials $computer

	Invoke-Command -ScriptBlock $sb -Credential $systemService_Credentials -Authentication Credssp -ComputerName $computer -ArgumentList $monitoring_connection, $monitoring_database, $persistence_connection, $persistence_database
}
