[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[Parameter(Mandatory=$true)]
	[string] $config,
	
	[switch] $reset
)

Add-PSSnapin Microsoft.SharePoint.Powershell -ea SilentlyContinue

. ..\Libraries\Standard_Functions.ps1

$global:logFile = ".\web_application_creation-" +  $(Get-Date).ToString("yyyyMMdd") + ".log"

Start-SPAssignment -Global

function HashTable_Output( [HashTable] $ht )
{
	$ht.Keys | % { $output += $_ + ":" + $ht[$_] + "," }
	return $output.TrimEnd(",")
}

function log_provision( [string] $txt )
{
	Write-Verbose $txt
	log -log $global:logFile -txt $txt
}


if ( -not ( Test-Path $config ) )
{
	Write-Error "Could not find $config"
}

$cfg = [xml] ( gc $config )

$dbs_servers = @()
$dbs_servers += Get-SPDatabase | where { $_.Type -eq "Content Database" } | Select -Expand Server -Unique 

if ( $dbs_servers.Count -eq 1 ) 
{
	$index = 0
}
else 
{
	$index = Get-Random -Min 0 -Max ($dbs_servers.Count-1)
	
}
$content_db_server = $dbs_servers[$index]

ForEach( $webApp in $cfg.WebApplications.WebApp )
{
	if( -not $webApp.ManagedAccount.Contains("USGTAD") )
	{
		$webApp.ManagedAccount = "USGTAD\" + $webApp.ManagedAccount
	}

	$acc = Get-SPManagedAccount $webApp.ManagedAccount -EA SilentlyContinue
	
	if( $acc -eq $nul )
	{
		$cred = Get-Credential $webApp.ManagedAccount
		New-SPManagedAccount $cred -verbose 
		$acc = Get-SPManagedAccount $webApp.ManagedAccount
	}

	$options = @{
		Name = $webApp.Name
		Port = $webApp.Port
		HostHeader = $webApp.HostHeader
		URL = "http://" + $webApp.HostHeader
		DatabaseName = $webApp.DatabaseName
		DatabaseServer = $content_db_server
		ApplicationPool = "AppPool - " + $webApp.HostHeader
		ApplicationPoolAccount = $acc
	}
	$aps = @()
	$webApp.Auth.type | % {
		if($_.Name -eq "NTLM" )
			{
				$aps += New-SPAuthenticationProvider
			}
		elseif($_.Name -eq "FBA" )
			{
				$aps += New-SPAuthenticationProvider -ASPNETMembershipProvider $_.provider -ASPNETRoleProviderName $_.role
			}  
		}
	
	if( $aps.count -gt 0 )
	{
		$options.Add( 'AuthenticationProvider', $aps )
	}

	log_provision -txt ("Going to create a new web application with the following options - " + (HashTable_Output $options)) 
	New-SPWebApplication @options -verbose 
	
	if( $webApp.ExtendHostHeader -ne $nul) 
	{
		$extendoptions = @{
			Name = $webApp.ExtendName
			Port = $webApp.ExtendPort
			HostHeader = $webApp.ExtendHostHeader
			URL = "http://" + $webApp.ExtendHostHeader
			zone = $webApp.ExtendZone
		}
		$AppURL = "http://" + $webApp.HostHeader
		log_provision -txt ("Going to extend web application with the following options - " + (HashTable_Output $extendoptions))
		Get-SPWebApplication -Identity $AppURL | New-SPWebApplicationExtension @ExtendOptions -verbose
	}
}


if( $reset ) 
{
	$web_servers = @()
	$web_servers = Get-SPServiceInstance | where { $_.TypeName -eq "Microsoft SharePoint Foundation Web Application" -and $_.Status -eq "Online" }  | Select Server
	$web_servers | % { 
		log_provision -txt ("Resetting IIS on - " + $_.Server.Address ) 
		#iisreset $_.Server.Address 
	} 
}
Stop-SPAssignment -Global 
