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
        
        $obj = New-Object PSObject -Property @{
            Name = $name
            State = $state
            User = $app_pool.WAMUserName
            Process = 0
            ThreadCount = 0
            WorkingSetSize = 0
            CreationDate = $(Get-Date -Date "1/1/1970")
        }
        
        if( $state -eq "Running" ) {
            $process = $processes | Where { $_.CommandLine -imatch $name }

            if( $process ) {
                $obj.ProcessId = $process.ProcessId
                $obj.ThreadCount = $process.ThreadCount
                $obj.WorkingSetSize = $process.WorkingSetSize
                $obj.CreationDate = $process.ConvertToDateTime( $process.CreationDate )
            }
        }
        $app_pools += $obj        
    }
}

return $app_pools