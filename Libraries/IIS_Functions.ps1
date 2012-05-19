Import-Module WebAdministration
Add-PSSnapin WebFarmSnapin -ErrorAction SilentlyContinue

$ENV:PATH += ';C:\Program Files\IIS\Microsoft Web Deploy V2'

function Create-WebFarm
{
	param(
		[Parameter(Mandatory=$true)]
		[string] $name,
		
		[Parameter(Mandatory=$true)]
		[string] $primary,
		
		[Object] $creds,
		[string[]] $members
	)
		
	if( $creds -eq $null ) 
	{ 
		Write-Host "Please enter an administrator account on all servers in the farm"
		$creds = Get-Credential 
	}
	
	New-WebFarm -WebFarm $name -Credentials $creds -Enabled -EnableProvisioning 
	New-Server -WebFarm $name -Address $primary -Enabled -IsPrimary
	Add-ServersToWebFarm -name $name -members $members
	
	return (Get-WebFarm -WebFarm $name)
}

function Add-ServersToWebFarm
{
	param(
		[Parameter(Mandatory=$true)]
		[string] $name,
		
		[Parameter(Mandatory=$true)]
		[string[]] $members
	)
	
	$members | % { New-Server -WebFarm $name -Address $_ -Enabled }
}

function Remove-ServersFromWebFarm
{
	param(
		[Parameter(Mandatory=$true)]
		[string] $name,
		
		[Parameter(Mandatory=$true)]
		[string[]] $members
	)
	
	$members | % { Remove-Server -WebFarm $name -Address $_ }
}

function Sync-WebFarm
{
	param(
		[Parameter(Mandatory=$true)]
		[string] $name,
	
		[ValidateSet("ProvisionPlatform", "ProvisionApplications")]
		[string] $op = "ProvisionApplications",
		
		[string] $server
	)
	
	$options = @{
		WebFarm = $name
		Name = $op
		SkipRestart = $true
		Force = $true
	}
	if( -not [string]::IsNullOrEmpty($server) ) { $options.Add("Address", $server) }
	
	Run-Operation @options
}

function Get-WebFarmServers
{
	param(
		[Parameter(Mandatory=$true)]
		[string] $name
	)
	
	$servers = Get-WebFarm -WebFarm $name | Select -Expand Servers | Select @{Name="Server";Expression={$_.Address}}
	
	return ($servers | Select -Expand Server)
}

function Get-WebFarmController
{
	param(
		[Parameter(Mandatory=$true)]
		[string] $name
	)
	
	$server = Get-WebFarm -WebFarm $name | Select -Expand PrimaryServer | Select @{Name="Server";Expression={$_.Address}}
	
	return ($server | Select -Expand Server)
}

function Get-WebFarmState
{
	param (
		[string] $name,
		[string] $server
	)
	
	$options = @{
		WebFarm = $name
	}
	if( -not [string]::IsNullOrEmpty($server) ) { $options.Add("Address", $server) }
	
	Write-Host $(Get-Date) "- Get Web Farm Information"
	Get-WebFarm -WebFarm $name
	
	Write-Host $(Get-Date) "- Get Web Farm Trace Messages"	
	Get-TraceMessage @options
	
	Write-Host $(Get-Date) "- Get Web Farm Active Operation"
	Get-ActiveOperation @options
	
	Write-Host $(Get-Date) "- Get Web Farm Server Requests"
	Get-ServerRequest @options
	
}

function Get-IISWebState
{
	param(
		[String[]] $computers
	)
	
	Invoke-Command -ComputerName $computers -ScriptBlock { 
		. d:\scripts\libraries\iis_functions.ps1
		Get-WebSite | Select Name, @{Name="State";Expression={(Get-WebSiteState $_.Name).Value}}, @{Name="Computer";Expression={$ENV:ComputerName}} 
	} | Select Name, State, Computer
}

function Start-IISSite
{
	param(
		[String[]] $computers,
		[String] $site = "Default Web Site"
	)
	
	Get-IISWebState $computers
	
	Write-Host "`nStarting $site . . . `n" -ForegroundColor blue
	
	Invoke-Command -ComputerName $computers -ScriptBlock { 
		param ( [string] $site )
		
		. d:\scripts\libraries\iis_functions.ps1
		Start-WebSite -name $site
	} -ArgumentList $site
	
	Get-IISWebState $computers
}

function Stop-IISSite
{
	param(
		[String[]] $computers,
		[String] $site = "Default Web Site"
	)
	
	Get-IISWebState $computers
	
	Write-Host "`nStoping $site . . . `n" -ForegroundColor blue
	
	Invoke-Command -ComputerName $computers -ScriptBlock { 
		param ( [string] $site )
		
		. d:\scripts\libraries\iis_functions.ps1
		Stop-WebSite -name $site
	} -ArgumentList $site
	
	Get-IISWebState $computers
}

function Add-DefaultDoc
{
	param(
		[String[]] $computers,
		[string] $site,
		[string] $file,
		[int] $pos = 0
	)
	
	Invoke-Command -ComputerName $computers -ScriptBlock { 
		param(
			[string] $site,
			[string] $file,
			[int] $pos = 0
		)
		
		. d:\scripts\libraries\iis_functions.ps1
		Add-WebConfiguration //defaultDocument/files "IIS:\sites\$site" -atIndex $pos -Value @{value=$file}
		Get-WebConfiguration //defaultDocument/files "IIS:\sites\$site" | Select -Expand Collection | Select @{Name="File";Expression={$_.Value}}
	} -ArgumentList $site, $file, $pos
}

function Create-IISWebSite
{
	param (
		[string] $site = $(throw 'A site name is required'),
		[string] $path = $(throw 'A physical path is required'),
		[int] $port = 80,
		[Object] $options = @{}
	)
	
	if( -not ( Test-Path $path) )
	{
		throw ( $path + " does not exist " )
	}

	New-WebSite -PhysicalPath $path -Name $site -Port $port @options
}

function Create-IISWebApp
{
	param (
		[string] $site = $(throw 'A site name is required'),
		[string] $app = $(throw 'An application name is required'),
		[string] $path = $(throw 'A physical path is required'),
		[Object] $options = @{}
		
	)	
	New-WebApplication -physicalPath $path -Site $site -Name $app @options
}

function Create-IISVirtualDirectory
{
	param (
		[string] $site = $(throw 'A site name is required'),
		[string] $vdir = $(throw 'An vdir (virtual directory name) is required'),
		[string] $path = $(throw 'A physical path is required'),
		[Object] $options = @{}
	)
	
	New-WebVirtualDirectory -Site $site -Name $vdir -physicalPath $path @options
}

function Create-IISAppPool
{
	param (
		[string] $apppool = $(throw 'An AppPool name is required'),
		[string] $user,
		[string] $pass,
		
		[ValidateSet("v2.0", "v4.0")]
		[string] $version = "v2.0"
	)

	New-WebAppPool -Name $apppool

	if( -not [String]::IsNullOrEmpty($user)  ) 
	{
		if( -not [String]::IsNullOrEmpty($pass) ) 
		{
			Set-ItemProperty "IIS:\apppools\$apppool" -name processModel -value @{userName=$user;password=$pass;identitytype=3}
		}
		else 
		{
			throw ($pass + " can not be empty if the user variable is defined")
		}
	}

	if( -not [String]::IsNullOrEmpty($version) )
	{
		Set-ItemProperty "IIS:\AppPools\$apppool" -name managedRuntimeVersion $version
	}

}

function Set-IISAppPoolforWebSite
{
	param (
		[string] $apppool = $(throw 'An AppPool name is required'),
		[string] $site = $(throw 'A site name is required'),
		[string] $vdir
	)
	if( [String]::IsNullOrEmpty($vdir) )
	{
		Set-ItemProperty "IIS:\sites\$site" -name applicationPool -value $apppool
	}
	else 
	{
		Set-ItemProperty "IIS:\sites\$site\$vdir" -name applicationPool -value $apppool
	}
}

function Set-SSLforWebApplication
{
	param (
		[string] $name,
		[string] $common_name,
		[Object] $options = @{}
	)
	
	Get-WebBinding $name
	
	$cert_thumprint = Get-ChildItem -path cert:\LocalMachine\My | Where { $_.Subject.Contains($common_name) } | Select -Expand Thumbprint
	New-WebBinding -Name $name -IP "*" -Port 443 -Protocol https @options
	cd IIS:\SslBindings
	Get-item cert:\LocalMachine\MY\$cert_thumprint | new-item 0.0.0.0!443

	Get-WebBinding $name
}

function Set-IISLogging
{
	param (
		[string] $site = $(throw 'A site name is required'),
		[string] $path = $(throw 'A physical path is required')
	)
	
	Set-ItemProperty "IIS:\Sites\$site" -name LogFile.Directory -value $path
	Set-ItemProperty "IIS:\Sites\$site" -name LogFile.logFormat.name -value "W3C"	
	Set-ItemProperty "IIS:\Sites\$site" -name LogFile.logExtFileFlags -value 131023
}