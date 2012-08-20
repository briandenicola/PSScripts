[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[Parameter(Mandatory=$true)]
	[string[]]
	$computers,
	
	[Parameter(Mandatory=$true)]
	[ValidateSet()]
	[string]
	$app,
	
	[switch]
	$full,
	
	[switch]
	$record,
	
	[string]
	$description
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

[regex]$pattern = "-ap ""(.+)"""
$url = "http://"
$list = "Issues Tracker"

$app_pool = @{"" = "" ;
	"" = "" ; 
}

$kill = {
	param ( [int] $p ) 
	Stop-Process -id $p -force
}


if( $full ) {
	$computers | % { 
		iisreset $_ /stop
		Start-sleep 5
		iisreset $_ /start
	}

	if($record) 
	{
		$obj = New-Object PSObject -Property @{
			Title = $app + " outage"
			User = $ENV:USERNAME
			Description = $computers + " - A Full IIS Reset was performed. " + $description
		}

		WriteTo-SPListViaWebService -url $url -list $list -Item $(Convert-ObjectToHash $obj) -TitleField Title
	}
	
	return
}

if ($pscmdlet.shouldprocess($computers, "Cycling AppPool - $appPools - on $computers") )
{
	.\stop_iis_app_pools.ps1 -computers $computers -app $app_pool[$app]

	gwmi win32_process -filter 'name="w3wp.exe"' -computer $computers | Select CSName, ProcessId, @{Name="AppPoolID";Expression={$pattern.Match($_.commandline).Groups[1].Value}} | where { $_.AppPoolID.Contains($app) } | %  {
		Write-Host -foreground red "Found a process that didn't stop so going to kill PID - " $_.ProcessId " on " $_.CSName 
		Invoke-Command -computer $_.CSName -script $kill -arg $_.ProcessId
	}

	.\start_iis_app_pools.ps1 -computers $computers -app $app_pool[$app]
	sleep 5
	.\query_iis_app_pools.ps1 -computers $computers

	if($record) 
	{
		$obj = New-Object PSObject -Property @{
			Title = $app + " outage"
			User = $ENV:USERNAME
			Description = $computers + " - " + $description
		}

		WriteTo-SPListViaWebService -url $url -list $list -Item $(Convert-ObjectToHash $obj) -TitleField Title
	}
}
