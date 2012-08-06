param (
	[String[]] $computers
)

. ..\libraries\Standard_Functions.ps1

Set-Variable -Option Constant -Name sql -Value "sp_help_job"
Set-Variable -Option Constant -Name dbs -Value "msdb"

function ConvertTo-Time( [int] $time )
{
	if( $time -eq 0 ) {
		return "00:00:00"
	} else {
		$time_string = $time.ToString()
	}
	
	if( $time_string.Length -eq 5 )
	{	
		$time_string = "0" + $time_string
	}
			
	return ( $time_string.SubString(0,2) + ":" + $time_string.SubString(2,2) + ":" + $time_string.SubString(4,2) )
}

function ConvertTo-Status( [int] $state )
{
	switch($state)
	{
		1 { $state_string = "running" }
		4 { $state_string = "idle" }
		5 { $state_string = "suspended" }
		default { $state_string = "unknown" }
	}
	
	return $state_string
}

$jobs = @()
$computers | % {
	Write-Host "Working on " $_
	$jobs += Query-DatabaseTable -server $_ -dbs $dbs -sql $sql | Where { $_.Enabled -eq 1 } |
		Select @{Name="Server";Expression={$_.originating_server}}, @{Name="JobName";Expression={$_.Name.Split(".")[0]}}, Owner, @{Name="Last Run Date";Expression={[datetime]::parseexact($_.last_run_date, "yyyyMMdd", $null)}}, @{Name="Last Run Time";Expression={ConvertTo-Time($_.last_run_time)}}, @{Name="Next Run Date";Expression={[datetime]::parseexact($_.next_run_date, "yyyyMMdd", $null)}}, @{Name="Next Run Time";Expression={ConvertTo-Time($_.next_run_time)}}, @{Name="Status"; Expression={ConvertTo-Status($_.current_execution_status)}}
}

return $jobs
