param (
	[string[]] $computers
)

[regex]$pattern = "-ap ""(.+)"""
Set-Variable -Option Constant -Name AppPoolQuery -Value "Select * from IIsApplicationPoolSetting"

function Get-AppPoolState( [int] $state )
{
	$app_pool_state = "Unknown or invalid state"
	
	switch( $state) 
 	{
		1 { $app_pool_state = "Starting" }
 		2 { $app_pool_state = "Running" }
 		3 { $app_pool_state = "Stopping"  }
 		4 { $app_pool_state = "Stopped" }
 	}
	
	return $app_pool_state
}

$computers | % { 
	
	$server = $_
	
	$wmiAppPoolSearcher = [WmiSearcher] $AppPoolQuery
	$wmiAppPoolSearcher.Scope.Path = "\\{0}\root\microsoftiisv2" -f $server
	$wmiAppPoolSearcher.Scope.Options.Authentication = 6
	$appPoolSettings = $wmiAppPoolSearcher.Get()
	
	Write-Host "--------------------------------------------------------------"
	$appPoolSettings | Select @{Name="Server";Expression={$server}},Name, @{Name="AppPool State";Expression={Get-AppPoolState -state $_.AppPoolState}} | ft
	gwmi win32_process -filter 'name="w3wp.exe"' -computer $server | Select Name, @{Name="Owner";Expression={$_.getOwner().user}}, @{Name="AppPool Name";Expression={$pattern.Match($_.commandline).Groups[1].Value}},ProcessId, ThreadCount, Handles, WorkingSetSize | fl
	Write-Host "--------------------------------------------------------------"
}




