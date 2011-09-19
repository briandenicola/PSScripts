Import-Module WebAdministration
if( (Get-PSSnapin | Where { $_.Name -eq "WebFarmSnapin" }) ) { Add-PSSnapin WebFarmSnapin }

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
