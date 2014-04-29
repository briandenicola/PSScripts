Set-Variable -Name now -Value ($(Get-Date).ToString("yyyyMMdd.hhmmss"))
Set-Variable -Name list_url -Value "" -Option Constant
Set-Variable -Name view -Value "" -Option Constant
Set-Variable -Name global:LogFile -Value (Join-Path $PWD.Path "logs\deployment-tracker-$now.log") -Option Constant

function Log-Event( [string] $txt, [switch] $toScreen ) 
{
	if( $toScreen ) { Write-Host "[" (Get-Date).ToString() "] - " $txt }
	"[" + (Get-Date).ToString() + "]," + $txt | Out-File $global:LogFile -Append -Encoding ASCII 
}

function Get-DestinationDirectory( [string] $url, [string] $server, [string] $zone )
{
	$sb = {
		param ( [string] $url, [string] $zone = "Default" )
		
		. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
		$web = Get-SPWebApplication ("http://" + $url)
		$iisSettings = $web.IisSettings			
		$zoneSettings = $iisSettings.GetEnumerator() | where { $_.Key -eq $zone }
		return ($zoneSettings.Value.Path).FullName
	}

	Log-Event -txt "Destination set to auto. Going to deteremine the IIS Home Directory for $url in the $zone zone" -toScreen 
	return ( Invoke-Command -ComputerName $server -Authentication CredSSP -Credential $global:Cred -ScriptBlock $sb -ArgumentList $url, $zone )	
}

function Get-SharePointFarmAndEnvironment( [string] $url )
{
	Log-Event -txt "Servers set to auto. Going to determine SharePoint Foundation Web Application farm and environment for $url" -toScreen 
	
	$webApp = Get-SPListViaWebService -Url $list_url -list WebApplications | 
        Where { $_.Uri -match ("(http|https)://" + $url) -and $_.Farm.Contains("2010") } |
        Select -first 1 Farm, Environment
	
	if( $webApp -ne $null ) {
		Log-Event -txt ("Found $url in " + $webApp.Farm + "'s " + $webApp.Environment + " environment") -toScreen
	}
	else {
		throw ("Could not find " + $url)
	}
	return $webApp
}

function Get-ServersToDeployTo( [string] $env, [string] $farm )
{	
    $sb_servers_to_deploy = {
		param ( 
            [string] $type = "Microsoft SharePoint Foundation Web Application"
        )
        . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
        Get-SPServiceInstance | Where { $_.TypeName -eq $type -and $_.Status -eq "Online" } | Select @{N="Servers";E={$_.Server.Address}} | Select -ExpandProperty Servers
	}

	Log-Event -txt "Configuration set to auto. Going to determine SharePoint Foundation Web Application servers for the $farm $env farm" -toScreen 
		
	$central_admin = Get-SPListViaWebService -Url $list_url -list Servers -view $view |
        Where { $_.Environment -eq $env -and $_.Farm -eq $farm } |
        Select -ExpandProperty SystemName
	
	if( $central_admin -ne $null )  {
		Log-Event -txt "Found central admin server - $central_admin" -toScreen
	} 
    else  {
		throw "Could not find a central admin server" 
	}

	$servers = Invoke-Command -Credential $global:Cred -Authentication CredSSP -ComputerName $central_admin -ScriptBlock $sb_servers_to_deploy 

    if( $servers -ne $null ) {
        Log-Event -txt ("Found the following servers that have the Web Application role online - " + $servers) -toScreen
    } 
    else {
	    throw "Could not find any servers on $central_admin for $url"
    }
	
	return $servers
}


function Get-DeploymentMap
{	
    param(
        [Parameter(Position=0,ValueFromPipeline=$true)]
        [object] $config,
        [string] $url
    )
	begin {
		$servers = @()
	}
	process {
		$default_file = $config.File
		
		if( $config.servers.type -eq "auto" ) {
			$web = Get-SharePointFarmAndEnvironment -url $url 
			$servers = Get-ServersToDeployTo -farm $web.Farm -env $web.Environment
		} 
        else {
			$servers = $config.servers.server
		}
			
		$map = @()
        foreach( $location in $config.locations.location ) {
			if( $location.destination -eq "auto" ) {
				$destination = Get-DestinationDirectory -url $url -server ($servers | select -First 1) -zone $location.name
			}
            else {
				$destination = $location.destination
			}
		
			if( -not [String]::IsNullOrEmpty($location.file) ) { $file = $location.file } else { $file = $default_file }
		
			$map += New-Object PSObject -Property @{ 
		 		Source =  $location.Source
				Destination = $destination
				Servers = $servers
				File = $file
			}
		}
	}
	end {
        foreach( $config in $map ) {
             Write-Verbose "VERBOSE: Map Section - $($config) ..."
        }
		return $map
	}
}

function Get-MostRecentFile([string] $src )
{
	return ( dir $src | ? { $_.name -notmatch "rolledback" } | sort LastWriteTime -desc | select -first 1 | Select -ExpandProperty Name )
}

function Backup-Config( [Object[]] $map )
{
    $sb_backup = {
		param( 
			[string] $source, 
			[string] $destination
		)
        . (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
		Copy-Item -Verbose -Force $source $destination
    }

	foreach( $config in $map ) {
		$source_file = Join-Path $config.Destination $config.File
		$backup_file = Join-Path $config.Source ($config.File + "." + $(Get-Date).ToString("yyyyMMddhhmmss"))
		
		if( $config.Servers -is [string] ) {
			$backup_server = $config.Servers
		}
		else {
			$backup_server = $config.Servers[0]
		}
		
		Write-Verbose $backup_server
		
		if ($pscmdlet.shouldprocess($backup_server, "Copying $source_file to $backup_file" ) ) {
			Log-Event -txt ("Backing up " + $config.File + " to " + $backup_file) -toScreen	
            Invoke-Command -ComputerName $backup_server -Authentication CredSSP -Credential $global:Cred `
                -ScriptBlock $sb_backup -ArgumentList $source_file, $backup_file
		}
	}
}

function Deploy-Config( [Object[]] $map )
{
    $sb_deploy = { 
		param( 
			[string] $source, 
			[string] $destination
		)

		. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
		if( (Get-Hash1 $source) -ne (Get-Hash1 $destination) ) {
			Copy-Item -Verbose -Force $source $destination
		}
		else {
			Write-Host "Skipped copy on" $env:COMPUTERNAME ". File hashes match" -ForegroundColor Yellow
		}
    }

	foreach( $config in $map ) {
		$most_recent_file = $config.Source + "\" + ( Get-MostRecentFile $config.Source )
		
		if ($pscmdlet.shouldprocess($config.Servers, "Deploying $most_recent_file" ) ) {
			Log-Event -txt ("Deploying $most_recent_file to " + $config.Destination + " on " + $config.Servers) -toScreen	
			Invoke-Command -ComputerName $config.Servers -Authentication CredSSP -Credential $global:Cred `
                -ScriptBlock $sb_deploy -ArgumentList $most_recent_file, (Join-Path $config.Destination $config.File)
		}
	}
}

function Validate-Config(  [Object[]] $map )
{ 
    $sb_validate ={ 
	    param( [string] $file )
	    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
	    "[{0}] : {1}" -f $ENV:ComputerName, (Get-Hash1 $file)	
    }

	foreach( $config in $map ) {
		$most_recent_file = $config.Source + "\" + ( Get-MostRecentFile $config.Source )
		"[Source File] : {0} = {1} " -f $most_recent_file,(Get-Hash1 $most_recent_file)
		
		Invoke-Command -ComputerName $config.Servers -ScriptBlock $sb_validate -ArgumentList (Join-Path $config.Destination $config.File)
	}
}
