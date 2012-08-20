################################
# Author: Brian Denicola
# Version: 
# Date:
# Notes:
################################

param (
	[string] $in = $(throw "An input CSV is required"),
	[string] $out = $(throw "An output location is required")
)

. ..\Libraries\Standard_Functions.ps1

"SystemName,Account,Farm,Environment,Exists" | Out-File -Encoding ascii $out

Import-Csv -Path $in | % {
	$farm = $_.Farm
	$env = $_.Environment
	$server = $_.SystemName 
	
	Write-progress -activity "Querying" -status "Querying $server"
	
	Get-LocalAdmins $server  | % { 
		"{0},{1},{2},{3},True" -f $server, $_, $farm, $env | Out-File -Append -Encoding ascii $out
	}
}
