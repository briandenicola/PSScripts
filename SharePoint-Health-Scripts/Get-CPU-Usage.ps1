param (
    [Alias("ComputerName")]
    [string[]] $servers,
	[int] $count = 5
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")

$counters = @(
	'\Processor(_total)\% Processor Time'
)

$results = Get-Counter -computer $servers -counter $counters -SampleInterval 1 -MaxSamples $count -EA SilentlyContinue  

$perfmon_results = @()
foreach( $result in $results )  {
	$timestamp = $result.TimeStamp	
	foreach( $value in $result.CounterSamples ) {
		$perfmon_results += ( New-Object PSObject -Property @{
			TimeStamp = $timestamp
			Server = $value.Path.Split("\")[2]
			Path = [regex]::matches( $value.Path, "\\\\(.*)\\\\(.*)" ).Groups[2].Value
			Instance = $value.InstanceName
			Value = $value.CookedValue
		})
	}
}
 
$perfmon_results | 
	Select  TimeStamp, Server, @{Name="Usage";Expression={ "{0:N2}" -f $_.Value }} | 
	Sort Server | 
	Format-Table -GroupBy Server