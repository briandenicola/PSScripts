function Create-ManagedMetadata
{
	param (
		[object] $cfg,
        [string] $env
	)

	$proxy_name = $cfg.Name + " Proxy"
	$app_name = "Managed Metadata Web Service"

    $farm = $cfg.SharePoint.Farms.farm | where { $_.name -eq $env }
	foreach( $server in $farm.Server | where { $_.role -eq "application" } ) {
		Write-Host "Working on $($server.name) . . ."	

    	$Guid = Get-SPServiceInstance -Server $server.name  | where {$_.TypeName -eq $app_name} | Select -Expand Id
        if( $Guid -ne $null ) {
	        Start-SPServiceInstance -Identity $Guid
		}
		else { 
			Write-Error "Could not find $app_name on $($server.name) . . . "
		}
	}
	
	try { 
		if( (Get-SPServiceApplication | where { $_.DisplayName -eq $cfg.Name }) ) {
			Write-Host "$($cfg.Name) already exists in this farm" -ForegroundColor Red
			return
		}

		# Start Services
		foreach( $server in $cfg.Servers.Server.Name ) { 
			Write-Host "[$(Get-Date)] - Attempting to start Managed Metadata on $server"
			Get-SPServiceInstance -Server $server | where { $_.TypeName -eq "Managed Metadata Web Service" } | Start-SPServiceInstance 
		}

		# Create Application Pool
		$pool = Get-SharePointApplicationPool -name $cfg.AppPool.name -account $cfg.AppPool.account

		$params = @{
			Name = $cfg.Name
			ApplicationPool = $pool
			DatabaseServer = $cfg.Databases.Database.instance
			DatabaseName = $cfg.Databases.Database.name
			AdministratorAccount = $cfg.Administrators
		}
		
		Write-Host "[$(Get-Date)] - Attempting to create Managed Metadata Service Application with the following parameters - "  (HashTable_Output $params)
		$app = New-SPMetadataServiceApplication @params -verbose
		New-SPMetadataServiceApplicationProxy -Name $proxy_name -ServiceApplication $app -DefaultProxyGroup
		
		Write-Host "[$(Get-Date)] - Attempting to publish Managed Metadata Service Application"
		Publish-SPServiceApplication $app
	}
	catch [System.Exception] {
		Write-Error ("The SharePoint Managed MetaData Configuration failed with the following Exception - " + $_.Exception.ToString() )
	}
}