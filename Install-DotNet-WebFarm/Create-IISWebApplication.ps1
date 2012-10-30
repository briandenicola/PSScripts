param (	
	[Parameter(Mandatory=$true)]
	[string] $config = ".\config.xml",
	
	[string] $log = ".\dotnet_webfarm_site_creation.log"
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")

Set-Variable -Name audit_ssl_script -Value "D:\Scripts\SSL\query_ssl_certificates.ps1" -Option Constant
Set-Variable -Name audit_iis_script -Value "D:\Scripts\IIS\Get-IISInfo.ps1" -Option Constant

function log( [string] $txt ) 
{
	$txt = "[" + (Get-Date).ToString() + "] - " + $txt + " . . . "	
	Write-Host $txt
	$txt | Out-File -Append -Encoding Ascii $log
}

function Get-AppPool( [string] $name )
{
	return ( Get-ItemProperty "IIS:\apppools\$name" )
}

function main
{
	$farm = $cfg.IISSites.WebFarm.Name
	$env = $cfg.IISSites.WebFarm.Environment
	
	$webFarm = Get-WebFarm -WebFarm $farm
	if( $webFarm -eq $null )
	{
		log -txt ( "Creating WebFarm " + $farm )	
		Create-WebFarm -name $farm -primary $ENV:COMPUTERNAME -members @($cfg.IISSites.WebFarm.Servers.Server)
	}
	$servers = Get-WebFarmServers -name $farm
	
	try
	{
		foreach( $site in $cfg.IISSites.Site )
		{	
			if( -not (Test-Path ("IIS:\Sites\" + $site.Name)) )
			{
				if( -not (Test-Path ("IIS:\AppPools\" + $site.AppPool.Name)) )
				{	
					log -txt ( "Creating AppPool " + $site.AppPool.Name + " with user " + $site.AppPool.User )
					Create-IISAppPool -apppool $site.AppPool.Name -user $site.AppPool.User -pass $site.AppPool.Pass -version $site.AppPool.Version				
				}
				
				if (-not (Test-Path $site.path))
				{
					log -txt ( "Creating Directory for " + $site.Name + " at path " + $site.Path )
					mkdir $site.path
				}
				
				log -txt ( "Creating WebSite " + $site.Name + " at path " + $site.Path )
				Create-IISWebSite -site $site.Name -path $site.Path -port $site.Port 
				Remove-WebBinding -name $site.Name -Port $site.port
				New-WebBinding -name $site.Name -Port $site.port -HostHeader $site.url
				
				log -txt ( "Setting Site " + $site.Name + " to use AppPool " + $site.AppPool.Name )
				Set-IISAppPoolforWebSite -site $site.Name -apppool $site.AppPool.Name
				
				if( $site.SSL.enable -eq "true" )
				{
					$working_directory = $PWD.Path
					log -txt ( "Setting up SSL for " + $site.Name )
					$secure_pass = ConvertTo-SecureString $site.SSL.pass -AsPlainText -Force 	
					Import-PfxCertificate -certpath $site.SSL.pfx -pfxPass $secure_pass
					Set-SSLforWebApplication -name $site.Name -common_name $site.SSL.subject
					cd $working_directory
					
					log -txt "Auditing SSL Configuraiton"
					&$audit_ssl_script -servers $servers -upload -parallel 
				}
				
				foreach( $command in $site.AdditionalCommands.command )
				{
					log -txt ( "Setting Additional Command " + $command.Name + " - " + $command.parameters )
					Invoke-Expression ( $command.Name, $command.Parameters -join " ")
				}
				
				log -txt ( "Starting " + $site.Name )
				Start-IISSite -computers "." -site $site.Name
				
				Get-Item ("IIS:\sites\" + $site.Name) | Select *
				
				log -txt ( "Syncing Farm " + $site.Name )
				Sync-WebFarm $farm
				
				log -txt ( "Auditing IIS Site for " + $site.Name )
				&$audit_iis_script -servers $servers -filter_type "url" -filter_value $site.Url -upload -farm $farm -env $env
				
			} else {
				log -txt ( $site.Name + " already exists on this web farm" )
			}
		}
		

		
	} catch [System.SystemException] {
		 Write-Host $_.Exception.ToString() -ForegroundColor Red
	}
}
$cfg = [xml] ( gc $config )
main