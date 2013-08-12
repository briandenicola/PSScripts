param (
	[string[]] $computers,
	[string[]] $appPools,
	[switch] $whatif
)

if( $Host.Version.Major -lt 2 ) {
	Write-Host "This script requires at least version 2.0 or higher"
	return
}

Get-WmiObject -Class IISApplicationPool -Namespace "root\microsoftiisv2" -ComputerName $computers -Authentication 6 | where { $appPools -contains $_.Name } | % { 
	if($whatif) {
		Write-Host "[WHATIF] Stopping " $_.Name " on " $_.__SERVER -foregroundcolor YELLOW
	} else {
		Write-Host "Stopping " $_.Name " on " $_.__SERVER -foregroundcolor RED	
	 	$_.Stop() 
	}
}
