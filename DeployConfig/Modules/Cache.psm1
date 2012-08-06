$SCRIPT:map = @{}

function Set-DeploymentMapCache { 
	param(
		[Object] $map,
		[string] $url
	)
	
	#$SCRIPT:map.Add( $url, $map )
	$SCRIPT:map[$url] = $map
}

function Get-DeploymentMapCache {
	param(
		[string] $url
	)
	
	return $SCRIPT:map[$url]
}

Export-ModuleMember -Function Get-DeploymentMapCache, Set-DeploymentMapCache
