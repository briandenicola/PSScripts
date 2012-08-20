param (
	[string] $config = "D:\Scripts\InstallSharePoint2010\config\master_setup.xml"
)

$global:farm_type = $null

Add-PsSnapin Microsoft.SharePoint.PowerShell -EA SilentlyContinue

function ConfigureServicesOnServer_CentralAdmin([String] $env)
{
	$farm = $cfg.SharePoint.Farms.farm | where { $_.name -eq $env }
	foreach( $server in $farm.Server | where { $_.role -eq "central-admin" } )
	{
		Write-Host "Working on " $server.name
		if( $server.name -ne $null -and (Get-SPServer -Identity $server.name -ErrorAction SilentlyContinue) -ne $null)
		{	
				foreach( $start_app in @("Microsoft SharePoint Foundation Incoming E-Mail","Microsoft SharePoint Foundation Web Application","Application Registry Service", "Business Data Connectivity Service", "Claims to Windows Token Service", "Document Conversions Load Balancer Service",  "Document Conversions Launcher Service") )
				{
					$Guid = Get-SPServiceInstance -Server $server.name  | where {$_.TypeName -eq $start_app} | Select -Expand Id
					Start-SPServiceInstance -Identity $Guid
				}
		}
		else
		{
			Write-Host [Warning] $_.name is not a server in this SharePoint farm.
		}
	}

}

function ConfigureServicesOnServer_Application([String] $env)
{
	$farm = $cfg.SharePoint.Farms.farm | where { $_.name -eq $env }
	foreach( $server in $farm.Server | where { $_.role -eq "application" } )
	{
		Write-Host "Working on " $server.name
		if( $server.name -ne $null -and (Get-SPServer -Identity $server.name -ErrorAction SilentlyContinue) -ne $null)
		{	
				foreach( $start_app in @("Application Registry Service", "Business Data Connectivity Service", "Claims to Windows Token Service") )
				{
					$Guid = Get-SPServiceInstance -Server $server.name  | where {$_.TypeName -eq $start_app} | Select -Expand Id
					Start-SPServiceInstance -Identity $Guid
				}
				
				foreach ( $stop_app in @("Microsoft SharePoint Foundation Web Application","Microsoft SharePoint Foundation Incoming E-Mail") )
				{
					$Guid = Get-SPServiceInstance -Server $server.name  | where {$_.TypeName -eq $stop_app} | Select -Expand Id
					Stop-SPServiceInstance -Identity $Guid -Confirm:$false
				}
		}
		else
		{
			Write-Host [Warning] $_.name is not a server in this SharePoint farm.
		}
	}
}

function ConfigureServicesOnServer_WFE([String] $env)
{
	$farm = $cfg.SharePoint.Farms.farm | where { $_.name -eq $env }
	foreach( $server in $farm.Server | where { $_.role -eq "wfe" } )
	{
		Write-Host "Working on " $server.name
		if( $server.name -ne $null -and (Get-SPServer -Identity $server.name -ErrorAction SilentlyContinue) -ne $null)
		{	
				foreach( $start_app in @("Microsoft SharePoint Foundation Sandboxed Code Service", "Word Automation Services", "Claims to Windows Token Service") )
				{
					$Guid = Get-SPServiceInstance -Server $server.name  | where {$_.TypeName -eq $start_app} | Select -Expand Id
					Start-SPServiceInstance -Identity $Guid
				}
				
				foreach ( $stop_app in @("Microsoft SharePoint Foundation Incoming E-Mail") )
				{
					$Guid = Get-SPServiceInstance -Server $server.name  | where {$_.TypeName -eq $stop_app} | Select -Expand Id
					Stop-SPServiceInstance -Identity $Guid -Confirm:$false
				}
		}
		else
		{
			Write-Host [Warning] $_.name is not a server in this SharePoint farm.
		}
	}
}

function ConfigureServicesOnServer_Custom([String] $env)
{
	$farm = $cfg.SharePoint.Farms.farm | where { $_.name -eq $env }
	foreach( $server in $farm.Server | where { $_.role -eq "custom" -or $_.role -eq "indexer"} )
	{
		Write-Host "Working on " $server.name
		if( $server.name -ne $null -and (Get-SPServer -Identity $server.name -ErrorAction SilentlyContinue) -ne $null)
		{					
				foreach ( $stop_app in @("Microsoft SharePoint Foundation Incoming E-Mail", "Microsoft SharePoint Foundation Web Application") )
				{
					$Guid = Get-SPServiceInstance -Server $server.name  | where {$_.TypeName -eq $stop_app} | Select -Expand Id
					Stop-SPServiceInstance -Identity $Guid -Confirm:$false
				}
		}
		else
		{
			Write-Host [Warning] $_.name is not a server in this SharePoint farm.
		}
	}
}

function ConfigureServicesOnServer_ServicesFarm([String] $env)
{
	$farm = $cfg.SharePoint.Farms.farm | where { $_.name -eq $env }
	foreach( $server in $farm.Server | where { $_.role -eq "application" } )
	{
		Write-Host "Working on " $server.name
		if( $server.name -ne $null -and (Get-SPServer -Identity $server.name -ErrorAction SilentlyContinue) -ne $null)
		{	
				foreach( $start_app in @( "Managed Metadata Web Service", "User Profile Service", "Web Analytics Web Service", "Web Analytics Data Processing Service") )
				{
					$Guid = Get-SPServiceInstance -Server $server.name  | where {$_.TypeName -eq $stop_app} | Select -Expand Id
					Start-SPServiceInstance -Identity $Guid
				}
		}
		else
		{
			Write-Host [Warning] $_.name is not a server in this SharePoint farm.
		}
	}
}

function main()
{	
	$xpath = "/SharePoint/Farms/farm/server[@name='" + $ENV:COMPUTERNAME + "']"
	$global:farm_type = (Select-Xml -xpath $xpath  $cfg | Select @{Name="Farm";Expression={$_.Node.ParentNode.name}}).Farm
	
	if( $global:farm_type -ne $null )
	{
		Write-Host "Found $ENV:COMPUTERNAME in $global:farm_type Farm Configuration"
	}
	else
	{
		throw "Could not find $ENV:COMPUTERNAME in configuration. Must exit"
	}
	
	ConfigureServicesOnServer_CentralAdmin($global:farm_type)
	ConfigureServicesOnServer_Application($global:farm_type)
	ConfigureServicesOnServer_WFE($global:farm_type)
	ConfigureServicesOnServer_Custom($global:farm_type)
	
	if ($global:farm_type -eq "services")
	{
		ConfigureServicesOnServer_ServicesFarm($global:farm_type)
 	}
}
$cfg = [xml] ( gc $config )
main