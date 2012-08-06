#############################
#Script - 
#Author - Brian Denicola
#############################
[CmdletBinding(SupportsShouldProcess=$true)]
param (

	[Parameter(Mandatory=$true)]
	[string] 
	$url,
	
	[Parameter(Mandatory=$true)]
    [ValidateSet("backup", "deploy", "validate")]
	[string] 
	$operation,
	
	[string]
	$cfg = '.\deploy.xml',

	[switch] $force
)

Import-Module .\Modules\cache.psm1
Import-Module ..\Libraries\Credentials.psm1

. ..\Libraries\Standard_functions.ps1
. ..\Libraries\SharePoint_functions.ps1


$now = $(Get-Date).ToString("yyyyMMdd.hhmmss")

$global:Version = "2.0.0"
$global:LogFile = $PWD.ToString() + "\logs\deployment-tracker-$now.log"

if( (Get-Creds) -eq $nul ) 
{
	Set-Creds
} 
$global:Cred = Get-Creds

$cfgFile = [xml]( gc $cfg )

function Log-Event( [string] $txt, [switch] $toScreen ) 
{
	if( $toScreen ) { Write-Host "[" (Get-Date).ToString() "] - 	" $txt }
	"[" + (Get-Date).ToString() + "]," + $txt | Out-File $global:LogFile -Append -Encoding ASCII 
}

function Get-DestinationDirectory( [string] $url, [string] $server, [string] $zone )
{
	$sb = {
		param ( [string] $url, [string] $zone = "Default" )
		
		Add-PSSnapin Microsoft.SharePoint.Powershell
		
		$web = Get-SPWebApplication ("http://" + $url)
		
		$iisSettings = $web.IisSettings
			
		$zoneSettings = $iisSettings.GetEnumerator() | where { $_.Key -eq $zone }
			
		return ($zoneSettings.Value.Path).FullName
	}

	Log-Event -txt "Destination set to auto. Going to deteremine the IIS Home Directory for $url in the $zone zone" -toScreen 
	return ( Invoke-Command -ComputerName $server -Authentication CredSSP -Credential $global:Cred -ScriptBlock $sb -ArgumentList $url, $zone )	
}

function Get-WFDestinationDirectory( [string] $site, [string] $server )
{
	$sb = {
		param ( [string] $site )
		
		Import-Module WebAdministration
		
		$web = Get-WebConfigFile "IIS:\sites\$site"
			
		return ($web.DirectoryName)
	}

	Log-Event -txt "Destination set to auto. Going to deteremine the IIS Home Directory for $url" -toScreen 
	return ( Invoke-Command -ComputerName $server -Authentication CredSSP -Credential $global:Cred -ScriptBlock $sb -ArgumentList $site )	
}

function Get-SharePointFarmAndEnvironment( [string] $url )
{
	Log-Event -txt "Servers set to auto. Going to determine SharePoint Foundation Web Application farm and environment for $url" -toScreen 

	$list_url = ""
	
	$webApp = get-SPListViaWebService -Url $list_url -list WebApplications | where { $_.Uri -match ("(http|https)://" + $url) -and $_.Farm.Contains("2010") } | Select -first 1 Farm, Environment
	
	if( $webApp -ne $null )
	{
		Log-Event -txt ("Found $url in " + $webApp.Farm + "'s " + $webApp.Environment + " environment") -toScreen
	}
	else 
	{
		throw ("Could not find " + $url)
	}
	return $webApp
	
}

function Get-WebFarmAndEnvironment( [string] $url )
{
	Log-Event -txt "Servers set to auto. Going to determine Web farm and environment for $url" -toScreen 

	$list_url = ""
	$view = "{}"
	
	$webApp = get-SPListViaWebService -Url $list_url -list WebSites -view $view | where { $_.URLs -match ("(http|https)://" + $url) } | Select -first 1 SiteName, Farm, Environment
	
	if( $webApp -ne $null )
	{
		Log-Event -txt ("Found $url in " + $webApp.Farm + "'s " + $webApp.Environment + " environment") -toScreen
	}
	else 
	{
		throw ("Could not find " + $url)
	}
	return $webApp
}

function Get-ServersToDeployTo( [string] $env, [string] $farm )
{	
	Log-Event -txt "Configuration set to auto. Going to determine SharePoint Foundation Web Application servers for the $farm $env farm" -toScreen 
	
	$list_url = ""
	$view = "{}"
		
	$central_admin = get-SPListViaWebService -Url $list_url -list Servers -view $view | where { $_.Environment -eq $env -and $_.Farm -eq $farm } | Select -ExpandProperty SystemName
	
	if( $central_admin -ne $null ) 
	{
		Log-Event -txt "Found central admin server - $central_admin" -toScreen
	} else 
	{
		throw "Could not find a central admin server" 
	}
	
	$servers = Invoke-Command -Credential $global:Cred -Authentication CredSSP -ComputerName $central_admin -ScriptBlock {
		param ( [string] $type )
		Add-PSSnapin Microsoft.SharePoint.Powershell
		Get-SPServiceInstance | where { $_.TypeName -eq $type -and $_.Status -eq "Online" } | Select Server
	} -ArgumentList "Microsoft SharePoint Foundation Web Application"
	 
	Log-Event -txt ("Found the following servers that have the Web Application role online - " + $servers) -toScreen
	
	return ($servers | ForEach-Object { $_.Server.Address })
}
function Get-ControllerToDeployTo( [string] $env, [string] $farm )
{	
	Log-Event -txt "Configuration set to auto. Going to determine Web Farm Controller for the $farm $env farm" -toScreen 
	
	$list_url = ""
	$view = "{}"
		
	$central_admin = get-SPListViaWebService -Url $list_url -list AppServers -view $view | where { $_.Environment -eq $env -and $_.Farm -eq $farm -and $_."WF Controller" -eq "1"} | Select -ExpandProperty SystemName
	
	if( $central_admin -ne $null ) 
	{
		Log-Event -txt "Found web farm controller - $central_admin" -toScreen
	} else 
	{
		throw "Could not find a web farm controller" 
	}
	
	$servers = Invoke-Command -Credential $global:Cred -Authentication CredSSP -ComputerName $central_admin -ScriptBlock {
		Add-PSSnapin WebFarmSnapin
		Get-WebFarm | where {$_.Enabled -eq "True" } | Select -Expand PrimaryServer | Select @{Name="Server";Expression={$_.Address}}
	}
	 
	Log-Event -txt ("Found the following servers that have the Web Farm online - " + $servers.Server) -toScreen
	
	return ($servers.Server)
}
function Get-DeploymentMap( [string] $url )
{	
	begin {
		$servers = @()
	}
	process {
		
		$config = $_
		
		$default_file = $config.File
		
		if( $config.servers.type -eq "auto" -and $config.type -eq "SP" )
		{
			Write-Host "Working on SharePoint $url . . ." -foregroundcolor yellow
			$web = Get-SharePointFarmAndEnvironment -url $url 
			$servers = Get-ServersToDeployTo -farm $web.Farm -env $web.Environment
		} 
		Elseif( $config.servers.type -eq "auto" -and $config.type -eq "WF" )
		{
			Write-Host "Working on Web Farm $url . . ." -foregroundcolor yellow
			$web = Get-WebFarmAndEnvironment -url $url 
			$servers = Get-ControllerToDeployTo -farm $web.Farm -env $web.Environment
		} 
		else 
		{
			$servers = $config.servers.server
		}
			
		$map = @()
		
		$config.locations.location | % { 
			if( $_.destination -eq "auto" -and $config.type -eq "SP" )
			{
				$destination = Get-DestinationDirectory -url $url -server ($servers | select -First 1) -zone $_.name
			}
			Elseif( $_.destination -eq "auto" -and $config.type -eq "WF" )
			{
				$destination = Get-WFDestinationDirectory -site $web.SiteName -server ($servers | select -First 1)
			}
			else
			{
				$destination = $_.destination
			}
		
			if( -not [String]::IsNullOrEmpty($_.file) ) { $file = $_.file } else { $file = $default_file }
		
			$map += New-Object PSObject -Property @{ 
		 		Source =  $_.Source
				Destination = $destination
				Servers = $servers
				File = $file
			}
		}
	}
	end {
		return $map
	}
}

function Get-MostRecentFile([string] $src )
{
	return ( dir $src | ? { $_.name -notmatch "rolledback" } | sort LastWriteTime -desc | select -first 1 | Select -ExpandProperty Name )
}

function Backup-Config( [Object[]] $map )
{
	$map | % { 
		$source_file = Join-Path $_.Destination $_.File
		$backup_file = Join-Path $_.Source ($_.File + "." + $(Get-Date).ToString("yyyyMMddhhmmss"))
		
		if( $_.Servers.GetType().Name -eq "String" )
		{
			$backup_server = $_.Servers
		}
		else
		{
			$backup_server = $_.Servers[0]
		}
		
		Write-Host $backup_server
		
		if ($pscmdlet.shouldprocess($backup_server, "Copying $source_file to $backup_file" ) )
		{
			Log-Event -txt ("Backing up " + $_.File + " to " + $backup_file) -toScreen	
			Invoke-Command -ComputerName $backup_server -Authentication CredSSP -Credential $global:Cred -ScriptBlock { 
				param( 
					[string] $source, 
					[string] $destination
				)
				. D:\Scripts\Libraries\Standard_Functions.ps1
				copy -Verbose -Force $source $destination
			} -ArgumentList $source_file, $backup_file
		}
	}
}

function Deploy-Config( [Object[]] $map )
{
	$map | % { 
		$most_recent_file = $_.Source + "\" + ( Get-MostRecentFile $_.Source )
		
		if ($pscmdlet.shouldprocess($_.Servers, "Deploying $most_recent_file" ) )
		{
			Log-Event -txt ("Deploying $most_recent_file to " + $_.Destination + " on " + $_.Servers) -toScreen	
			
			Invoke-Command -ComputerName $_.Servers -Authentication CredSSP -Credential $global:Cred -ScriptBlock { 
				param( 
					[string] $source, 
					[string] $destination
				)
				. D:\Scripts\Libraries\Standard_Functions.ps1
				if( (get-hash1 $source) -ne (get-hash1 $destination) )
				{
					copy -Verbose -Force $source $destination
				}
				else
				{
					Write-Host "Skipped copy on" $env:COMPUTERNAME ". File hashes match" -ForegroundColor Yellow
				}
				
			} -ArgumentList $most_recent_file, (Join-Path $_.Destination $_.File)
		}
	}
}

function Validate-Config(  [Object[]] $map )
{ 
	$map | % { 
		$most_recent_file = $_.Source + "\" + ( Get-MostRecentFile $_.Source )
		"[Source File] : {0} = {1} " -f $most_recent_file,(get-hash1 $most_recent_file)
		
		Invoke-Command -ComputerName $_.Servers -ScriptBlock { 
			param( [string] $file )
			. D:\Scripts\Libraries\Standard_Functions.ps1
			"[{0}] : {1}" -f $ENV:ComputerName, (get-hash1 $file)	
		} -ArgumentList (Join-Path $_.Destination $_.File)
	}
}

function main() 
{

	$url = $url -replace ("http://|https://")

	Write-Host "Working on $url . . ." -foregroundcolor yellow

	try { 
		$cfg = $cfgFile.configs.config | Where { $_.Url -eq $url }

		if( $cfg -eq $nul )
		{
			throw "Could not find an entry for the URL in the XML configuration"
		}
	
		$deployment_map = Get-DeploymentMapCache -url $url 
		if( $deployment_map -eq $nul -or $force -eq $true )
		{
			$deployment_map = $cfg | Get-DeploymentMap -url $url
			Set-DeploymentMapCache -map $deployment_map -url $url
		}

		if( ($deployment_map | Select -First 1 Source).Source -eq $nul )
		{	
			throw  "Could not find any deployment mappings for the url"
		}
		
		switch($operation)
		{
			backup 		{ Backup-Config $deployment_map }
			validate	{ Validate-Config $deployment_map }
			deploy		{ Deploy-Config $deployment_map }
			
			default 
			{			
				Write-Host "Usage: DeployConfigs.ps1 -url <url of site> -operation <backup, deploy,validate> [-cfg <path_to_xml> -whatif -help]"
				Quit	
			}
		}
	}
	catch [Exception]
	{
		Write-Error ("Exception has occured with the following message - " + $_.Exception.ToString())
	}
}
main
