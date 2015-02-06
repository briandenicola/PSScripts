param ( 
	[string] $app,
	[string] $site,
	[string] $db_name,
	[switch] $restore
)

Add-PSSnapin Microsoft.SharePoint.Powershell

$db_server = "sql"
$db = Get-SPContentDatabase -ConnectAsUnattachedDatabase -DatabaseName $db_name -DatabaseServer $db_server
	
$restored_site = $db | Get-SPSite -Limit All | Where ServerRelativeUrl -imatch $site
$restored_file = Join-Path $ENV:TEMP ($site + "-backup-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".bak")

if( $restored_site -ne $null ) {
	Backup-SPSite -Identity $restored_site -Path $restored_file -Verbose

	if( $restore ) {
		$recover_url = $app + $restored_site.ServerRelativeUrl
		$org_site = Get-SPSite $recover_url -Limit All -EA SilentlyContinue
		if( $org_site -eq $null ) { 
			Restore-SPSite $recover_url -Path $restored_file -Verbose
		}
		else { 
			Write-Error "The site - $site - was already found in $app. Will not restore automatically. Backup of file can be found at - $restored_file"
		}
	}
	else { 
		Write-Host "The site - $site - has been backed up to -  $restored_file"
	}
}
else { 
	Write-Error "No site name - $site - was found in $db_name on $db_server"
}