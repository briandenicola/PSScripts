Set-Variable -Name SCRIPT:map -Value @{}
Set-Variable -Name session -Value $null -Option Private

Set-Variable -Name sb_servers_to_deploy -Value [scriptblock]{
	param ( 
        [string] $type = "Microsoft SharePoint Foundation Web Application"
    )
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
    Get-SPServiceInstance | Where { $_.TypeName -eq $type -and $_.Status -eq "Online" } | Select @{N="Servers";E={$_.Server.Address}} | Select -ExpandProperty Servers
} -Option Private

Set-Variable -Name sb_iis_home_directory -Value [scriptblock]{
	param ( [string] $url, [string] $zone = "Default" )
		
	. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint2010_Functions.ps1")
	$web = Get-SPWebApplication ("http://" + $url)
	$iisSettings = $web.IisSettings			
	$zoneSettings = $iisSettings.GetEnumerator() | where { $_.Key -eq $zone }
	return ($zoneSettings.Value.Path).FullName
} -Option Private

function _Get-RemotePSSession
{
    param(
        [string] $remote_server
    )

    if($session -eq $null) {
        $session = New-PSSession -ComputerName $remote_server -Authentication CredSSP -Credential $global:Cred
    }
    
    return $session 
}

function _Get-SPIISHomeDirectory
{
    param(
        [string] $url, 
        [string] $server, 
        [string] $zone
    )

	Log-Event -txt "Destination set to auto. Going to deteremine the IIS Home Directory for $url in the $zone zone" -toScreen 
	$home_directory = Invoke-Command -Session (_Get-RemotePSSession -remote_server $server) -ScriptBlock $sb_iis_home_directory -ArgumentList $url, $zone
    return $home_directory
}

function _Get-SPServersForComponent
{	
    param(
        [string] $central_admin
    )

	Log-Event -txt "Configuration set to auto. Going to determine SharePoint Foundation Web Application servers for the $farm $env farm" -toScreen 

	$servers = Invoke-Command -Session (_Get-RemotePSSession -remote_server $server) -ScriptBlock $sb_servers_to_deploy 
    if( $servers -ne $null ) {
        Log-Event -txt ("Found the following servers that have the Web Application role online - " + $servers) -toScreen
    } 
    else {
	    throw "Could not find any servers on $central_admin for $url"
    }
	
	return $servers
}


function Create-DeploymentMap
{	
    param(
        [Parameter(Position=0,ValueFromPipeline=$true)]
        [object] $config,
        [string] $url
    )
	
	Set-Variable -Name servers -Value @()

	if( $config.servers.type -ieq "sharepoint" ) {
		$servers = _Get-SPServersForComponent -central_admin $config.servers.server
	}
    elseif( $config.servers.type -ieq ".net" ) {
        $servers = $config.servers.server #Feature is coming but for now treat as manual
    }
    else {
		$servers = $config.servers.server
	}
			
	$map = @()
    foreach( $location in $config.locations.location ) {
		if( $location.destination -eq "auto" ) {
			$destination = _Get-SPIISHomeDirectory -url $url -server $central_admin -zone $location.name
		}
        else {
			$destination = $location.destination
		}
		
		$map += New-Object PSObject -Property @{ 
		 	Source =  $location.Source
			Destination = $destination
			Servers = $servers
			File = $location.file
		}
	}

    foreach( $config in $map ) {
            Write-Verbose "VERBOSE: Map Section - $($config) ..."
    }
	return $map
}


function Set-DeploymentMapCache { 
	param(
		[Object] $map,
		[string] $url
	)
	
	$SCRIPT:map[$url] = $map
}

function Get-DeploymentMapCache {
	param(
		[string] $url
	)
	
	return $SCRIPT:map[$url]
}

Export-ModuleMember -Function Create-DeploymentMap,Get-DeploymentMapCache, Set-DeploymentMapCache