[CmdletBinding(SupportsShouldProcess=$true)]
param ( 
    [Parameter(Mandatory=$true)]
    [string] $ComputerName
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\IIS_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Variables.ps1")

Set-Variable -Name web_counter     -Value "\Web Service(_Total)\Current Connections"
Set-Variable -Name lb_monitor_site -Value "Default Web Site"
Set-Variable -Name impact_limit    -Value 2

function Write-HashTableOutput( [HashTable] $ht )
{
	$ht.Keys | % { $output += $_ + ":" + $ht[$_] + "," }
	return $output.TrimEnd(",")
}

function Drain-IISConnections
{
    param( [string] $ComputerName )

	Stop-IISSite -computers $ComputerName -Name $lb_monitor_site
    Get-IISWebState -computers $ComputerName 

	$i = 0
	do {
		Start-Sleep -Seconds 10
		$active_connections = Get-PerformanceCounters -counters $web_counter -computers $ComputerName -samples 1 -interval 1 | Select -ExpandProperty CookedValue
		$i++
        Write-Host -NoNewline "."
	} while ( $i -lt 12 -and $active_connections -ge $impact_limit )
    Write-Host "."	
}

function Get-IISPerformanceData
{
    param( [string] $ComputerName )

    Set-Variable -Name counters        -Value @("\Processor(_total)\% Processor Time","\Memory\Available MBytes","\PhysicalDisk(*)\Current Disk Queue Length")
    $performance_data = @{}

    $sb = { 
        . ( Join-Path $ENV:SCRIPTS_HOME "libraries\IIS_Functions.ps1")
    
        $app_pools = @()
        foreach( $app_pool in (Get-ChildItem IIS:\AppPools) ) {

            
            $sites = @(Get-Website | Where { $_.ApplicationPool -eq $app_pool.Name } | Select -Expand Name)

            $obj = New-Object PSObject -Property @{
                Computer = $ENV:COMPUTERNAME
                AppPoolName = $app_pool.Name
                State =  $app_pool.State
                User = if( [string]::IsNullOrEmpty($app_pool.processModel.UserName) ) { $app_pool.processModel.identityType } else { $app_pool.processModel.UserName }
                Version = $app_pool.ManagedRuntimeVersion
                ProcessId = 0
                Threads = 0
                Handles = 0
                MemoryInGB = 0
                CreationDate = $(Get-Date -Date "1/1/1970")
                Sites = if( [string]::IsNullOrEmpty($sites)) { [string]::Empty } else { [string]::join( ";" , $sites  ) }
                PendingRequests = [string]::Empty
            }        
        
            $worker_process = $app_pool.workerProcesses.Collection | Select -First 1
            if( $worker_process.state -eq "Running" ) {
                $process = Get-Process -id $worker_process.processId
                $requests = @(Get-AppPool-Requests -appPool $app_pool.Name)
               
                $obj.ProcessId = $process.Id
                $obj.Threads = $process.Threads.Count
                $obj.Handles = $process.HandleCount
                $obj.MemoryInGB = [math]::round( $process.WorkingSet64 / 1gb, 2)
                $obj.CreationDate = $process.StartTime
                $obj.PendingRequests = if( [string]::IsNullOrEmpty($requests)) { [string]::Empty } else { [string]::join(";",$requests) }
            }  
            $app_pools += $obj
        }
        return $app_pools
    }

    $performance_data.Add( "AppPoolStats", (Invoke-Command -ComputerName $ComputerName -ScriptBlock $sb) )
    $performance_data.Add( $web_counter,   (Get-PerformanceCounters -counters $web_counter -computers $ComputerName -samples 1 -interval 1 | Select -ExpandProperty CookedValue) )
    foreach( $counter in $counters ) {
          $performance_data.Add( $counter, (Get-PerformanceCounters -counters $counter -computers $ComputerName -samples 1 -interval 1 | Select -ExpandProperty CookedValue))
    }

    $performance_data
}

function Start-IIS
{
    param( [string] $ComputerName )
	Get-Service -ComputerName $ComputerName -Name W3SVC | Start-Service -Verbose
    Start-IISSite -computers $ComputerName -Name $lb_monitor_site
}

function Stop-IIS
{
    param( [string] $ComputerName )
	Get-Service -ComputerName $ComputerName -Name W3SVC | Stop-Service -Verbose
}

Drain-IISConnections -ComputerName $ComputerName
$metrics = Get-IISPerformanceData -ComputerName $ComputerName
Stop-IIS -ComputerName $ComputerName
Start-IIS -ComputerName $ComputerName

$obj = New-Object PSObject -Property @{
    Title = ("Cycled IIS and gathered metrics on {0} " -f $ComputerName)
    User = $ENV:USERNAME
    Description = ("Process information gather:`n")
}

foreach( $key in $metrics.Keys ) {
    if($metrics.$key -is [Array] ) {
         $obj.Description += ("{0}:" -f $key)
        foreach( $value in $metrics.$key ) {
            $obj.Description += ("`t{0}`n" -f $value )
        }
    } 
    else {
        $obj.Description += ("{0} - {1}`n" -f $key, $metrics.$key)
    }
}


Write-Output -InputObject ("Gathered Information on IIS from {0}" -f $ComputerName)
$obj | Format-List
WriteTo-SPListViaWebService -url $global:SharePoint_url -list $global:SharePoint_issues_list -Item $(Convert-ObjectToHash $obj) -TitleField Title