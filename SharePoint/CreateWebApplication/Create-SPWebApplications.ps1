[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_})]
	[string] $config,
	[switch] $reset
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")

Set-Variable -Name logFile -Value  (Join-Path $PWD.Path ("web_application_creation-" +  $(Get-Date).ToString("yyyyMMdd") + ".log"))
Set-Variable -Name ssl -Value "443" -Option Constant
Set-Variable -Name domain -Value "EXAMPLE"

function HashTable_Output( [HashTable] $ht )
{
	$ht.Keys | % { $output += $_ + ":" + $ht[$_] + "," }
	return $output.TrimEnd(",")
}

function log_provision( [string] $txt )
{
	Write-Verbose $txt
	log -log $logFile -txt $txt
}

function Get-DatabaseServer
{
    Set-Variable -Name index -Value 0
	
    $dbs_servers = @( Get-SPDatabase | where { $_.Type -eq "Content Database" } | Select -Expand Server -Unique )
	if ( $dbs_servers.Count -ne 1 ) {
		$index = Get-Random -Min 0 -Max ($dbs_servers.Count-1) 
	}

	return $dbs_servers[$index]
}

$cfg = [xml] ( Get-Content $config )
$content_db_server = Get-DatabaseServer

foreach( $webApp in $cfg.WebApplications.WebApp ) {
	if( -not $webApp.ManagedAccount.Contains($domain) ) {
		$webApp.ManagedAccount = "{0}\{1}" -f $domain,$webApp.ManagedAccount
	}

	$managed_account = Get-SPManagedAccount $webApp.ManagedAccount -EA SilentlyContinue
	if( $managed_account -eq $nul ) {
		$cred = Get-Credential $webApp.ManagedAccount
		New-SPManagedAccount $cred -verbose 
		$managed_account = Get-SPManagedAccount $webApp.ManagedAccount
	}

	$options = @{
		Name = $webApp.Name
		Port = $webApp.Port
		HostHeader = $webApp.HostHeader
		DatabaseName = $webApp.DatabaseName
		DatabaseServer = $content_db_server
		ApplicationPool = "AppPool - " + $webApp.HostHeader
		ApplicationPoolAccount = $managed_account
	}
	
    if( $webApp.Port -eq $ssl ) {
        $app_url = "https://{0}" -f $webApp.HostHeader
        $options.Add('URL', $app_url)
        $options.Add('SecureSocketsLayer', $true)
    }
    else {
        $app_url = "http://{0}" -f $webApp.HostHeader
        $options.Add('URL', $app_url)
    }

	$auth_provider = @()
	foreach( $auth in $webApp.Auth.type ) {
		if($auth.Name -eq "NTLM") {
			$auth_provider += New-SPAuthenticationProvider
		}
		elseif($auth.Name -eq "FBA") {
			$auth_provider += New-SPAuthenticationProvider -ASPNETMembershipProvider $auth.provider -ASPNETRoleProviderName $auth.role
		}  
	}
	
	if( $auth_provider.count -gt 0 ) {
		$options.Add( 'AuthenticationProvider', $auth_provider )
	}

	log_provision -txt ("Going to create a new web application with the following options - " + (HashTable_Output $options)) 
	New-SPWebApplication @options -verbose 
	
	if( $webApp.ExtendHostHeader -ne $nul ) {
		$extendoptions = @{
			Name = $webApp.ExtendName
			Port = $webApp.ExtendPort
			HostHeader = $webApp.ExtendHostHeader
			Zone = $webApp.ExtendZone
		}

        if( $webApp.ExtendPort -eq $ssl ) {
            $extendoptions.Add('URL', ("https://{0}" -f $webApp.ExtendHostHeader))
            $extendoptions.Add('SecureSocketsLayer', $true)
        }
        else {
            $app_url = 
            $extendoptions.Add('URL', ("http://{0}" -f $webApp.ExtendHostHeader))
        }

		log_provision -txt ("Going to extend web application with the following options - " + (HashTable_Output $extendoptions))
		Get-SPWebApplication -Identity $app_url | New-SPWebApplicationExtension @ExtendOptions -verbose
	}
}

if( $reset ) {
	$web_servers = @( Get-SPServiceInstance | where { $_.TypeName -eq "Microsoft SharePoint Foundation Web Application" -and $_.Status -eq "Online" }  | Select Server )
	foreach( $server in $web_servers ) {
		log_provision -txt ( "Resetting IIS on - " + $_.Server.Address ) 
		iisreset $_.Server.Address 
	}
} 