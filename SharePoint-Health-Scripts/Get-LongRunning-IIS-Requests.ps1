param (
	[string[]] $servers = $sp.Filter("ext","pro","spw|p10|p11"),
    [int] $duration = "10000",
    [string] $appPool = "AppPool - team.gt.com"
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")

$sb = { 
    param( [string] $app )
    . (Join-Path $ENV:SCRIPTS_HOME "Libraries\iis_functions.ps1")
    Get-AppPool-Requests $app
}

Invoke-Command -computer $servers -ScriptBlock $sb -ArgumentList $appPool |
    Where timeElapsed -gt $duration  | 
    Sort timeElapsed -desc | 
    Select Url, timeElapsed, Verb, PSComputerName |
    Format-list 