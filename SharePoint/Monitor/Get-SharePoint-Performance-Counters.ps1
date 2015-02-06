[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[Parameter(Mandatory=$true)]
	[string[]] $computers,

    [Parameter(Mandatory=$true)]
    [ValidateSet("Memory","Processor","Disk", "Web","Network","SharePoint")]
    [string] $counter,

	[string] $file = [String]::Empty
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")

$all_counters = @(
	'\ASP.NET\Request Execution Time',
	'\ASP.NET\Requests Rejected', 
	'\ASP.NET\Requests Queued ',
	'\ASP.NET\Worker Process Restarts',
	'\ASP.NET\Request Wait Time',
	'\Memory\Available MBytes',
	'\Memory\% Committed Bytes In Use',
	'\Memory\Pool Nonpaged Bytes',
	'\Network Interface(*)\Bytes Total/sec',
	'\Network Interface(*)\Packets/sec',
	'\PhysicalDisk(*)\Current Disk Queue Length',
	'\PhysicalDisk(*)\% Disk Time',
	'\PhysicalDisk(*)\Disk Transfers/sec',
	'\PhysicalDisk(*)\Avg. Disk sec/Transfer',
	'\Processor(*)\% Processor Time',
	'\System\Processor Queue Length',
	'\Web Service(*)\Bytes Received/sec',
	'\Web Service(*)\Bytes Sent/sec',
	'\Web Service(*)\Current Connections',
	'\Web Service(*)\Get Requests/sec',
	'\SharePoint Foundation(*)\Sql Query Executing  time',
	'\SharePoint Foundation(*)\Executing Sql Queries',
	'\SharePoint Foundation(*)\Responded Page Requests Rate',
	'\SharePoint Foundation(*)\Executing Time/Page Request',
	'\SharePoint Foundation(*)\Current Page Requests',
	'\SharePoint Foundation(*)\Reject Page Requests Rate',
	'\SharePoint Foundation(*)\Incoming Page Requests Rate',
	'\SharePoint Foundation(*)\Active Threads'
)

if( [string]::IsNullOrEmpty($counter) ) { 
    $counters = $all_counters
}
else {
    $counters = $all_counters | Where { $_ -imatch $counter } 
}

Set-Variable -Name samples -Value 10 -Option Constant
Set-Variable -Name interval -Value 1 -Option Constant 

$results = Get-Counter -computer $computers -counter $counters -SampleInterval $interval -MaxSamples $samples -EA SilentlyContinue  

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
 
if( $file -eq [String]::Empty ) { 
	return ($perfmon_results | Sort Path -Descending)
} else {
	$perfmon_results | Export-Csv -NoTypeInformation -Encoding Ascii $file
}
 