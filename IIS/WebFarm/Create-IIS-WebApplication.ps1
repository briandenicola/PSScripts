param (	
	[Parameter(Mandatory=$true)]
	[string] $config = ".\config.xml",
	[switch] $record,
	[string] $log = ".\dotnet_webfarm_site_creation.log"
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")

Set-Variable -Name audit_ssl_script -Value (Join-Path $ENV:SCRIPTS_HOME "SSL\Query-SSL-Certificates.ps1") -Option Constant
Set-Variable -Name audit_iis_script -Value (Join-Path $ENV:SCRIPTS_HOME "IIS\Get-IISInfo-IIS7.ps1") -Option Constant

function log( [string] $txt ) 
{
	$txt = "[" + (Get-Date).ToString() + "] - " + $txt + " . . . "	
	Write-Host $txt
	$txt | Out-File -Append -Encoding Ascii $log
}

function Get-AppPool( [string] $name )
{
	return ( Get-ItemProperty ( Join-Path "IIS:\AppPools" $name ) )
}

function main
{
	$env = $cfg.IISSites.WebFarm.Environment
	
	try	{
		foreach( $site in $cfg.IISSites.Site )	{	
			if( Test-Path (Join-Path "IIS:\Sites" $site.Name)) {
                log -txt ( $site.Name + " already exists on this server" )
                continue
            }
            
			if( -not (Test-Path (Join-Path "IIS:\AppPools" $site.AppPool.Name)) ) {	
				log -txt ( "Creating AppPool " + $site.AppPool.Name + " with user " + $site.AppPool.User )
				Create-IISAppPool -apppool $site.AppPool.Name -user $site.AppPool.User -pass $site.AppPool.Pass -version $site.AppPool.Version				
			}
				
			if (-not (Test-Path $site.path)) {
				log -txt ( "Creating Directory for " + $site.Name + " at path " + $site.Path )
				New-Item -ItemType Directory $site.path
			}
				
			log -txt ( "Creating WebSite " + $site.Name + " at path " + $site.Path )
			Create-IISWebSite -site $site.Name -path $site.Path -port $site.Port 
			Remove-WebBinding -name $site.Name -Port $site.port
			New-WebBinding -name $site.Name -Port $site.port -HostHeader $site.url
				
			log -txt ( "Setting Site " + $site.Name + " to use AppPool " + $site.AppPool.Name )
			Set-IISAppPoolforWebSite -site $site.Name -apppool $site.AppPool.Name
				
			if( $site.SSL.enable -eq "true" ) {
				$working_directory = $PWD.Path
				log -txt ( "Setting up SSL for " + $site.Name )
				$secure_pass = ConvertTo-SecureString $site.SSL.pass -AsPlainText -Force 	
				Import-PfxCertificate -certpath $site.SSL.pfx -pfxPass $secure_pass
				Set-SSLforWebApplication -name $site.Name -common_name $site.SSL.subject
				Set-Location $working_directory
				
				if( $record ) { 
					log -txt "Auditing SSL Configuraiton"
					&$audit_ssl_script -servers $ENV:COMPUTERNAME -upload 
				}
			}
				
			foreach( $command in $site.AdditionalCommands.command )	{
				log -txt ( "Setting Additional Command " + $command.Name + " - " + $command.parameters )
				Invoke-Expression ( $command.Name, $command.Parameters -join " ")
			}
				
			log -txt ( "Starting " + $site.Name )
			Start-IISSite -computers "." -site $site.Name
			
			Get-Item ("IIS:\sites\" + $site.Name) | Select *
						
			if( $record ) { 
				log -txt ( "Auditing IIS Site for " + $site.Name )
				&$audit_iis_script -servers $ENV:COMPUTERNAME -filter_type "url" -filter_value $site.Url -upload -env $env
			}
		}
	} 
	catch [System.SystemException] {
		 Write-Host $_.Exception.ToString() -ForegroundColor Red
	}
}
$cfg = [xml] ( gc $config )
main