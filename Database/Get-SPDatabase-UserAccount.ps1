#######
## Script: 
## Author: Brian Denicola
## Version: 
## Purpose:
## Updates:
#######

. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

$nameMethod = [Microsoft.Sharepoint.Administration.SPDatabase].getMethod("get_Name")
$serverMethod = [Microsoft.Sharepoint.Administration.SPDatabase].getMethod("get_Server")
$instanceMethod = [Microsoft.Sharepoint.Administration.SPDatabase].getMethod("get_ServiceInstance")
$userMethod = [Microsoft.Sharepoint.Administration.SPDatabase].getMethod("get_Username")
$conMethod = [Microsoft.Sharepoint.Administration.SPDatabase].getMethod("get_DatabaseConnectionString")

$content_db_info = @()

Get-SPWebApplication -name * | % { 

	$webApp = $_.Name.ToString()
	$app_pool_user = $_.ApplicationPool.UserName
	
	foreach( $db in $_.ContentDatabases )
	{	
		$user = $userMethod.Invoke($db, "instance,public", $null, $null, $null)
		if( $user -eq $null ) { $user = $app_pool_user } 
		
		$content_db_info += ( New-Object PSObject -Property @{
			Name = $nameMethod.Invoke($db, "instance,public", $null, $null, $null)
			Server = ($serverMethod.Invoke($db, "instance,public", $null, $null, $null)).DisplayName.ToString()
			Instance = ($instanceMethod.Invoke($db, "instance,public", $null, $null, $null)).DisplayName.ToString()
			User = $user
			ConnectionString = $conMethod.Invoke($db, "instance,public", $null, $null, $null)
			
		})
	}
}

return $content_db_info