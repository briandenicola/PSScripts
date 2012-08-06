#######
## Script: 
## Author: Brian Denicola
## Version: 
## Purpose:
## Updates:
#######

param (
	[string] $webApp
)

$ENV:Path += ";c:\Program Files\Common Files\Microsoft Shared\web server extensions\12\bin"

. ..\Libraries\Standard_functions.ps1
. ..\Libraries\SharePoint_functions.ps1

$nameMethod = [Microsoft.Sharepoint.Administration.SPDatabase].getMethod("get_Name")
$instanceMethod = [Microsoft.Sharepoint.Administration.SPDatabase].getMethod("get_ServiceInstance")

get-SPWebApplication -name $webApp  | % { 

	$_.ContentDatabases | % {

		$dbsName = $nameMethod.Invoke($_, "instance,public", $null, $null, $null)
		$dbsInstance = $instanceMethod.Invoke($_, "instance,public", $null, $null, $null)

		Write-host "Verbose: stsadm.exe -o deletecontentdb -url " $webApp.AlternateUrls[0].Uri.ToString " -databasename $dbsName -databaseserver " $dbsInstance.DisplayName.ToString()
		stsadm.exe -o deletecontentdb -url $webApp.AlternateUrls[0].Uri.ToString -databasename $dbsName -databaseserver $dbsInstance.DisplayName.ToString()
		
	}
}