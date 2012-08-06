#######
## Script: 
## Author: Brian Denicola
## Version: 
## Purpose:
## Updates:
#######

param (
	[string] $file,
	[switch] $upload
)

. ..\Libraries\Standard_functions.ps1
. ..\Libraries\SharePoint_functions.ps1

$doclib = ""

$sql = "sp_helpfile"

$nameMethod = [Microsoft.Sharepoint.Administration.SPDatabase].getMethod("get_Name")
$serverMethod = [Microsoft.Sharepoint.Administration.SPDatabase].getMethod("get_Server")
$instanceMethod = [Microsoft.Sharepoint.Administration.SPDatabase].getMethod("get_ServiceInstance")

$MB = 1024

function get-fromDatabase ( $cmd, $connection ) 
{
	$conn = New-Object -TypeName System.Data.SqlClient.SqlConnection
	$conn.ConnectionString = $connection
	$conn.Open()
	
	$sqlcmd = New-Object System.Data.SqlClient.SqlCommand $cmd,$conn
	$sqlcmd.ExecuteReader()
	
	$conn.Close()
}


$out = "WebApplication, Database Server, Database Instance, File Name, Size`n"
get-SPWebApplication -name * | % { 

	$webApp = $_.Name.ToString()
	
	$_.ContentDatabases | % {

		$dbsName = $nameMethod.Invoke($_, "instance,public", $null, $null, $null)
		$dbsInstance = $instanceMethod.Invoke($_, "instance,public", $null, $null, $null)

		$conStr = "Server={0};Database={1};Trusted_Connection=yes" -f $dbsInstance.DisplayName.ToString(),$dbsName
		
		get-fromDatabase -cmd $sql -connection $conStr | % { 
			$out += $webApp + "," + $dbsInstance.DisplayName.ToString() + "," + $dbsName + "," + $_.Item(2).ToString() + "," + $([math]::round( [int]$_.Item(4).TrimEnd("KB") / 1024)) + "`n"
		}
	}
}

if( $file -eq "" ) { Write-Host $Out } else { $out | out-file $file -encoding ASCII }
if( $upload ) { WriteTo-Sharepoint $doclib $file }