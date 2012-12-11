param (
	[string] $config = "D:\Scripts\InstallSharePoint2010\config\master_setup.xml"
)

$global:farm_type = $null

Add-PsSnapin Microsoft.SharePoint.PowerShell -EA SilentlyContinue

function Configure-CentralAdmin-Roles([String] $env)
{
	$ca_roles = @(
		"Microsoft SharePoint Foundation Incoming E-Mail",
		"Microsoft SharePoint Foundation Web Application",
		"Application Registry Service", 
		"Business Data Connectivity Service", 
		"Claims to Windows Token Service", 
		"Document Conversions Load Balancer Service", 
		"Document Conversions Launcher Service")
		
	$farm = $cfg.SharePoint.Farms.farm | where { $_.name -eq $env }
	foreach( $server in $farm.Server | where { $_.role -eq "central-admin" } )
	{
		Write-Host "Working on " $server.name
		if( $server.name -ne $null -and (Get-SPServer -Identity $server.name -ErrorAction SilentlyContinue) -ne $null)
		{	
				foreach( $start_app in $ca_roles )
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

function Configure-WFE-Roles([String] $env)
{
	$wfe_roles = @(
		"Microsoft SharePoint Foundation Sandboxed Code Service",
		"Word Automation Services",
		"Claims to Windows Token Service",
		"Secure Store Service",
		"Access Database Service", 
		"Visio Graphics Service"
		"Application Registry Service", 
		"Business Data Connectivity Service")
		
	$farm = $cfg.SharePoint.Farms.farm | where { $_.name -eq $env }
	foreach( $server in $farm.Server | where { $_.role -eq "wfe" } )
	{
		Write-Host "Working on " $server.name
		if( $server.name -ne $null -and (Get-SPServer -Identity $server.name -ErrorAction SilentlyContinue) -ne $null)
		{	
				foreach( $start_app in $wfe_roles )
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

function Configure-WFE-Roles-ServicesFarm([String] $env)
{
	$services_roles = @( "Managed Metadata Web Service", "User Profile Service", "Web Analytics Web Service", "Web Analytics Data Processing Service")
	$farm = $cfg.SharePoint.Farms.farm | where { $_.name -eq $env }
	foreach( $server in $farm.Server | where { $_.role -eq "application" } )
	{
		Write-Host "Working on " $server.name
		if( $server.name -ne $null -and (Get-SPServer -Identity $server.name -ErrorAction SilentlyContinue) -ne $null)
		{	
				foreach( $start_app in $services_roles )
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
	
	Configure-CentralAdmin-Roles($global:farm_type)
	Configure-WFE-Roles($global:farm_type)
	
	if ($global:farm_type -eq "services")
	{
		Configure-WFE-RoleservicesFarm($global:farm_type)
 	}
}
$cfg = [xml] ( gc $config )
main
