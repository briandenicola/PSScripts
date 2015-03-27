[CmdletBinding(SupportsShouldProcess=$true)]
param ( 
    [Parameter(Mandatory=$true)]
    [string] $server,
    [string] $log
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")

$counter = "\Web Service(_Total)\Current Connections"
$default_site = "Default Web Site"
$impact_limit = 2

$url = ""
$list = "Issues Tracker"

function Stop-Site-Gracefully 
{
    param( [string] $server )

	Stop-IISSite -computers $server -Name $default_site
    Get-IISWebState -computers $server 

	$i = 0
	do {
		Start-Sleep -Seconds 10
		$active_connections = Get-PerformanceCounters -counters $counter -computers $server -samples 1 -interval 1 | Select -ExpandProperty CookedValue
		$i++
        Write-Host -NoNewline "."
	} while ( $i -lt 12 -and $active_connections -ge $impact_limit )
    Write-Host "."	

	return $active_connections 
}

function Start-Site
{
    param( [string] $server )
	Start-IISSite -computers $server -Name $default_site
}

function Start-IIS
{
    param( [string] $server )
	iisreset /start $server
}

function Stop-IIS
{
    param( [string] $server )
	iisreset /stop $server
}

function main 
{
    $active_connections = Stop-Site-Gracefully -server $server		

    Stop-IIS -server $server
    Start-IIS -server $server
    Start-Site -server $server

    $obj = New-Object PSObject -Property @{
        Title = "Gracefully Cycled IIS on " + $server
        User = $ENV:USERNAME
        Description = "[ $(Get-Date) ] - IIS on $server was cycled. $active_connections connections were impacted..."
    }

    Write-Host $obj
    WriteTo-SPListViaWebService -url $url -list $list -Item $(Convert-ObjectToHash $obj) -TitleField Title
}
main