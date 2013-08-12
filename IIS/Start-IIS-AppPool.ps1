[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [Parameter(Mandatory=$true)]
	[string[]] $computer,

    [Parameter(Mandatory=$true)]
	[string[]] $AppPool
)

if( $Host.Version.Major -lt 2 ) {
	Write-Host "This script requires at least version 2.0 or higher"
	return
}

$process =  Get-WmiObject -Class IISApplicationPool -Namespace "root\microsoftiisv2" -ComputerName $computer -Authentication 6 | where { $_.Name -imatch ("W3SVC/APPPOOLS/" + $appPool) }

if( $process ) {
    if ($pscmdlet.shouldprocess($computers, "Start AppPool - $appPool - on $computer") ) {
        Write-Host "Starting $($process.Name) on  $($process.__SERVER)" -foregroundcolor GREEN	
        $process.Start() 
    }
}
else { 
    Write-Error "Could not find $AppPool on $computer ..."
}
