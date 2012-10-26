param ( 
	[string] $app,
	[string] $site,
	[string] $db_name
)

Add-PSSnapin Microsoft.SharePoint.Powershell

$db_server = "sql"
$db = Get-SPContentDatabase -ConnectAsUnattachedDatabase -DatabaseName $db_name -DatabaseServer $db_server
	
$restored_site = $db | Get-SPSite -Limit All | Where ServerRelativeUrl -match $site
$restored_file = Join-Path $ENV:TEMP ("temp-restore-" + $(Get-Date).ToString("yyyyMMddhhmmss") + ".bak")

if( -not $restored_site ) {
	Backup-SPSite -Identity $restored_site -FilePath $restored_file

	if( -not (Get-SPSite ($app + "/" + $site) -Limit All ) ) { 
		Restore-SPSite ($app + "/" + $site) -File $restored_file -Verbose
	}
	else { 
		Write-Error "The site - $site - was already found in $app. Will not restore automatically. Backup of file can be found at - $restored_file"
	}
}
else { 
	Write-Error "No site name - $site - was found in $db_name on $db_server"
}