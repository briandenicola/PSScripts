param (
    [Alias("ComputerName")]
	[string[]] $servers,
	[string] $process = "w3wp.exe"
)

Get-WmiObject Win32_Process -ComputerName $servers -Filter ("Name='{0}'" -f $process )  | 
	Select PSComputerName, Name, @{Name="Owner";Expression={$_.getOwner().user}}, ProcessId, @{Name="Memory";Expression={[math]::floor($_.WorkingSetSize/1mb)}}, Handles, ThreadCount |
	Sort PSComputerName |
	Format-Table -GroupBy PSComputerName