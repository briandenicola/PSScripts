[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string[]] $computers,
	
    [Parameter(Mandatory = $true)]
    [string] $app_pool,
    [switch] $full,
    [switch] $record
)

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")
. (Join-Path $ENV:SCRIPTS_HOME "Libraries\SharePoint_Functions.ps1")

[regex] $pattern = "-ap ""(.+)"""

Set-Variable -Name url -Value "http://"
Set-Variable -Name list -value "Issues Tracker"
Set-Variable -Name kill -Value {
    param ( [int] $p ) 
    Stop-Process -id $p -force
}

function Get-AppPool {
    param(
        [string] $computer
    )

    return (
        Get-WmiObject -Class IISApplicationPool -Namespace "root\microsoftiisv2" -ComputerName $computer -Authentication 6 |
            Where { $_.Name -imatch ("W3SVC/APPPOOLS/" + $appPool) }
    )
}

function Start-AppPool {
    param(
        [string] $computer
    )

    $process = Get-AppPool -computer $computer -app $appPool

    if ( $process ) {
        Write-Host "Starting $($process.Name) on $($process.__SERVER)" -foregroundcolor GREEN	
        $process.Start() 
    }
    else { 
        throw "Could not find $AppPool on $computer ..."
    }
}

function Stop-AppPool {
    param(
        [string] $computer
    )

    $process = Get-AppPool -computer $computer -app $appPool

    if ( $process ) {
        Write-Host "Starting $($process.Name) on $($process.__SERVER)" -foregroundcolor GREEN	
        $process.Stop() 
    }
    else { 
        throw "Could not find $AppPool on $computer ..."
    }
}

function Kill-Process {
    param(
        [string] $computer
    )

    Get-WmiObject win32_process -filter 'name="w3wp.exe"' -computer $computer | 
        Select CSName, ProcessId, @{N = "AppPoolID"; E = {$pattern.Match($_.commandline).Groups[1].Value}} | 
        Where { $_.AppPoolID -eq $app_pool } | 
        ForEach-Object {
        Write-Host -foreground red "Found a process that didn't stop so going to kill PID - " $_.ProcessId " on " $_.CSName 
        Invoke-Command -computer $_.CSName -script $kill -arg $_.ProcessId
    }
}

function main {
    if ( $full ) {
        foreach ( $computer in $computers ) { 
            iisreset $computer /stop
            Start-sleep 5
            iisreset $computer /start
        }

        $obj = New-Object PSObject -Property @{
            Title       = $app_pool + " outage"
            User        = $ENV:USERNAME
            Description = $computers + " - A Full IIS Reset was performed."
        }
    }
    else {
        
        foreach ( $computer in $computers ) {
            Stop-AppPool -computer $computer
            Kill-Process -computer $computer
            Start-AppPool -computer $computer
        }

        $obj = New-Object PSObject -Property @{
            Title       = $app_pool + " outage"
            User        = $ENV:USERNAME
            Description = $computers + " - An Application Pool was cycled."
        }  
    }
    
    if ($record) {
        WriteTo-SPListViaWebService -url $url -list $list -Item $(Convert-ObjectToHash $obj) -TitleField Title
    }	
    return
}
main 