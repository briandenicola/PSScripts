param (
    [Parameter(Mandatory=$true)]
	[string[]] $computers
)

Set-Variable -Option Constant -Name AppPoolQuery -Value "Select * from IIsApplicationPoolSetting"

function Get-AppPoolState( [int] $state )
{
	$app_pool_state = "Unknown or invalid state"
	
	switch( $state ) 
 	{
		1 { $app_pool_state = "Starting" }
 		2 { $app_pool_state = "Running" }
 		3 { $app_pool_state = "Stopping"  }
 		4 { $app_pool_state = "Stopped" }
 	}
	
	return $app_pool_state
}

$app_pools = @()
foreach( $computer in $computers ) {
		
	$wmiAppPoolSearcher = [WmiSearcher] $AppPoolQuery
	$wmiAppPoolSearcher.Scope.Path = "\\{0}\root\microsoftiisv2" -f $computer
	$wmiAppPoolSearcher.Scope.Options.Authentication = 6
	$appPoolSettings = $wmiAppPoolSearcher.Get()
	
    $processes = Get-WmiObject -class win32_process -filter 'name="w3wp.exe"' -computer $computer

    foreach( $app_pool in $appPoolSettings ) {
        $name = $app_pool.Name.Split("/")[2]
        $state = Get-AppPoolState -state $app_pool.AppPoolState
        
        $hash = [ordered] @{
            Computer = $computer
            Name = $name
            State =  $state
            User = if( [string]::IsNullOrEmpty($app_pool.WAMUserName) ) { "Application Identity" } else { $app_pool.WAMUserName }
            Version = if( [string]::IsNullOrEmpty($app_pool.ManagedRuntimeVersion) ) { "v1.1|v2.0" } else { $app_pool.ManagedRuntimeVersion } 
            ProcessId = 0
            ThreadCount = 0
            MemoryInGB = 0
            CreationDate = $(Get-Date -Date "1/1/1970")
        }

        $obj = New-Object PSObject -Property $hash
        
        if( $state -eq "Running" ) {
            $process = $processes | Where { $_.CommandLine -imatch $name }

            if( $process ) {
                $obj.ProcessId = $process.ProcessId
                $obj.ThreadCount = $process.ThreadCount
                $obj.MemoryInGB = [math]::round( $process.WorkingSetSize / 1gb, 2)
                $obj.CreationDate = $process.ConvertToDateTime( $process.CreationDate )
            } 
            else {
                $obj.State = "Idle"
            }
        }
        $app_pools += $obj        
    }
}

return $app_pools