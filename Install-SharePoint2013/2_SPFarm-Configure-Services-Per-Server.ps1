param (
	[string] $config = "D:\Scripts\InstallSharePoint2010\config\master_setup.xml"
)

$global:farm_type = $null

Add-PsSnapin Microsoft.SharePoint.PowerShell -EA SilentlyContinue

function Configure-CentralAdmin-Role
{
    param ( 
        [string] $type
    )

	$ca_roles = @(
		"Microsoft SharePoint Foundation Incoming E-Mail",
		"Microsoft SharePoint Foundation Web Application",
		"Claims to Windows Token Service", 
    )
		
	$farm = $cfg.SharePoint.Farms.farm | where { $_.name -eq $type }
	foreach( $server in $farm.Server | where { $_.role -eq "central-admin" -or $_.role -eq "all" } ) {
		Write-Host "Working on $($server.name) . . ."
		if( $server.name -ne $null -and (Get-SPServer -Identity $server.name -EA SilentlyContinue) -ne $null) {
            Write-Host "[Warning] $($_.name) is not a server in this SharePoint farm. Skipping"	
            continue
        }
		
		foreach( $start_app in $ca_roles ) {
			$Guid = Get-SPServiceInstance -Server $server.name  | where {$_.TypeName -eq $start_app} | Select -Expand Id
			Start-SPServiceInstance -Identity $Guid
    	}
	}

}

function Configure-WFE-Roles
{
    param (
        [string] $type
    )

	$wfe_roles = @(
		"Microsoft SharePoint Foundation Sandboxed Code Service",
		"Claims to Windows Token Service",
		"Secure Store Service",
		"Access Database Service", 
		"Visio Graphics Service"
		"Application Registry Service", 
        "Work Management Service",
        "App Management Service",
        "Request Management"
    )
		
	$farm = $cfg.SharePoint.Farms.farm | where { $_.name -eq $type }
	foreach( $server in $farm.Server | where { $_.role -eq "wfe" -or $_.role -eq "all" } ) {
		Write-Host "Working on $($server.name) . . ."
		if( $server.name -ne $null -and (Get-SPServer -Identity $server.name -ErrorAction SilentlyContinue) -ne $null) {
            Write-Host "[Warning] $($_.name) is not a server in this SharePoint farm. Skipping"	
            continue
        }	
		
		foreach( $start_app in $wfe_roles )	{
			$Guid = Get-SPServiceInstance -Server $server.name  | where {$_.TypeName -eq $start_app} | Select -Expand Id
			Start-SPServiceInstance -Identity $Guid
		}
				
		foreach ( $stop_app in @("Microsoft SharePoint Foundation Incoming E-Mail") ) {
			$Guid = Get-SPServiceInstance -Server $server.name  | where {$_.TypeName -eq $stop_app} | Select -Expand Id
			Stop-SPServiceInstance -Identity $Guid -Confirm:$false
		}
	}
}

function Configure-ServicesFarm-Roles([String] $env)
{
	$services_roles = @(
        "Managed Metadata Web Service", 
        "User Profile Service", 
    )

	$farm = $cfg.SharePoint.Farms.farm | where { $_.name -eq $env }
	foreach( $server in $farm.Server | where { $_.role -eq "application" } ) {
		Write-Host "Working on $($server.name) . . ."
		if( $server.name -ne $null -and (Get-SPServer -Identity $server.name -ErrorAction SilentlyContinue) -ne $null) {
            Write-Host "[Warning] $($_.name) is not a server in this SharePoint farm. Skipping"	
            continue
        }		

		foreach( $start_app in $services_roles ) {
			$Guid = Get-SPServiceInstance -Server $server.name  | where {$_.TypeName -eq $stop_app} | Select -Expand Id
			Start-SPServiceInstance -Identity $Guid
		}
	}
}

function main()
{	
	$xpath = "/SharePoint/Farms/farm/server[@name='" + $ENV:COMPUTERNAME + "']"
	$global:farm_type = (Select-Xml -xpath $xpath  $cfg | Select @{Name="Farm";Expression={$_.Node.ParentNode.name}}).Farm
	
	if( $global:farm_type -ne $null ) {
		Write-Host "Found $ENV:COMPUTERNAME in $global:farm_type Farm Configuration"
	}
	else {
		throw "Could not find $ENV:COMPUTERNAME in configuration. Must exit"
	}
	
	Configure-WFE-Roles -type $global:farm_type
	Configure-CentralAdmin-Roles -type $global:farm_type 
	
	if ($global:farm_type -eq "services" -or $global:farm_type -eq "standalone") {
		Configure-ServicesFarm-Roles -type $global:farm_type
 	}
}
$cfg = [xml] ( gc $config )
main
