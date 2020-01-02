<#
.SYNOPSIS
The script display process utilization on the current system

.DESCRIPTION
Version - 1.0.0
The script display process utilization on the current system

.EXAMPLE
.\Get-CpuLoad.ps1

.EXAMPLE
.\Get-CpuLoad.ps1 -RefreshRate 2 -Filter 15

.PARAMETER RefreshRate
How fast in seconds to refresh the screen. Default 1 second
Valid Range - 0 to 5 seconds 

.PARAMETER Filter 
How many processes to display
Valid Range - 5 to 25 

#>

param(
    [ValidateRange(0.0,5.0)]
    [double] $RefreshRate = 1,
    [ValidateRange(5,25)]
    [int] $Filter = 10
)
function Get-UtilizationPercentage {
    param(
        [int64] $cpu_time_1,
        [int64] $cpu_time_2,
        [int64] $time_1,
        [int64] $time_2
    )
    return [math]::Round((($cpu_time_1 - $cpu_time_2) / ($time_1 - $time_2)) * 100, 2)
}

$query = "select Name,IDProcess,ThreadCount,WorkingSetPrivate,PercentProcessorTime,Timestamp_Sys100NS from Win32_PerfRawData_PerfProc_Process"

Clear-Host
while (1) {
    $process_utlization = Get-CimInstance -Query $query

    Write-Output "Gather statistics . . ."
    Start-Sleep -Seconds $RefreshRate
    
    $process_utlization_delta = Get-CimInstance -Query $query

    $system_utilization = foreach ( $process in $process_utlization ) {
        $delta = $process_utlization_delta | 
            Where-Object { $_.IDProcess -eq $process.IDProcess -and $_.Name -eq $process.Name } |
            Select-Object PercentProcessorTime, Timestamp_Sys100NS

        $cpu_properties = @{
            cpu_time_1 = $delta.PercentProcessorTime 
            cpu_time_2 = $process.PercentProcessorTime
            time_1 = $delta.Timestamp_Sys100NS
            time_2 = $process.Timestamp_Sys100NS
        }
        $cpu_utilization = Get-UtilizationPercentage @cpu_properties

        $properties = [ordered] @{
            ProcessName   = $process.Name
            PID           = $process.IDProcess
            ThreadCount   = $process.ThreadCount
            PercentageCPU = $cpu_utilization
            WorkingSetKB  = $process.WorkingSetPrivate / 1kb
        }
        New-Object psobject -Property $properties 
    }

    Clear-Host
    
    $system_utilization | 
        Sort-Object -Property PercentageCPU -Descending | 
        Select-Object -First $Filter | 
        Format-Table -AutoSize
    
    #Start-Sleep -Seconds $RefreshRate
}
