[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[string] $config = ".\config\master_setup.xml"
)

$global:farm_type = $null
$global:server_type = $null

Add-PsSnapin Microsoft.SharePoint.PowerShell -EA SilentlyContinue

. .\Libraries\Setup_Functions.ps1

function main()
{	
	$global:farm_type = Get-FarmType
		
	Configure-WFE-Roles -type $global:farm_type
	Configure-CentralAdmin-Roles -type $global:farm_type 
	
	if ($global:farm_type -eq "services" -or $global:farm_type -eq "standalone") {
		Configure-ServicesFarm-Roles -type $global:farm_type
 	}
}
$cfg = [xml] ( gc $config )
main
