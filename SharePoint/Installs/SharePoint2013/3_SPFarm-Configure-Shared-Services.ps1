[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[string] $config = ".\config\master_setup.xml"
)

Add-PSSnapin Microsoft.SharePoint.PowerShell –erroraction SilentlyContinue
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Setup_Functions.ps1")
. .\Libraries\Setup-ManagedMetaData.ps1
. .\Libraries\Setup-UserProfile.ps1
. .\Libraries\Setup-Search.ps1
. .\Libraries\Setup_Functions.ps1

function main()
{
	$log = $cfg.SharePoint.BaseConfig.LogsHome + "\Farm-Shared-Service-Application-Setup-" + $ENV:COMPUTERNAME + "-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".log"
	Start-Transcript -Append -Path $log

    $global:farm_type = Get-FarmType

	Write-Host "[ $(Get-Date) ] - Configure Initial Cert Exchange (Publishing Side)"
	Config-InitialPublishing -farm_type $global:farm_type
	
	$metadata_cfg = $cfg.SharePoint.SharedServices.Service | where { $_.App -eq "Metadata" }
	if( $metadata_cfg -ne $null ) {
		Write-Host "[ $(Get-Date) ] - Create Managed Metadata Service Application"
		Create-ManagedMetadata -cfg $metadata_cfg
	}
	
	$search_cfg = $cfg.SharePoint.SharedServices.Service | where { $_.App -eq "EnterpriseSearch" }
	if( $search_cfg -ne $null ) {	
		Write-Host "[ $(Get-Date) ] - Create Enterprise Search Service Application"
		Write-Host "`t Note: This script only creates the shell of Enterprise Search on one Search Server"
		Write-Host "`t The final setup of the search topology requires manual work: "
		Create-EnterpriseSearch -cfg $search_cfg
	}
	
	$user_profile_cfg = $cfg.SharePoint.SharedServices.Service | where { $_.App -eq "UserProfile" }
	if( $user_profile_cfg -ne $null ) {
		Write-Host "[ $(Get-Date) ] - Create User Profile Service Application"
		Write-Host "`t Note: This script only creates the shell of the User Profile."
		Write-Host "`t The following requires manual work: "
		Write-Host "`t 1.) Start the User Profile Synchronization Service"
		Write-Host "`t 2.) Setup a connection to Active Directory "
		Write-Host "`t 3.) Setup a Synchronization Schedule"
		Write-Host "`t 4.) Setup Profile Filters"
		Create-UserProfile -cfg $user_profile_cfg
	}	
	Stop-Transcript
}
$cfg = [xml] (gc $config)
main
