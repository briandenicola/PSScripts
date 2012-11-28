[CmdletBinding(SupportsShouldProcess=$true)]
param ( 
	[Parameter(Mandatory=$true)]	
    [string[]] $computers,
    [switch] $upload,
	[switch] $sharepoint
)

. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-PATH $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

if( $sharepoint ) {
	$global:url =  "http://teamadmin.gt.com/sites/ApplicationOperations/"
	$global:list = "Servers"
}
else { 
	$global:url =  "http://teamadmin.gt.com/sites/ApplicationOperations/applicationsupport/"
	$global:list = "AppServers"
}

foreach( $server in $computers ) { 
	$properties = audit-Server $server 
	
	if( $upload ) {
		Write-Verbose "[ $(Get-Date) ] - Upload was passed on command line. Will upload results to $global:url ($global:list)  . . . "
		WriteTo-SPListViaWebService -url $global:url -list $global:list -Item $(Convert-ObjectToHash $properties) -TitleField SystemName 
	}
	else {
		return $properties
	}
}