﻿param (
    [string] $pull_server,
    [string] $guid
)

configuration ConfigureDSCPullServer {
        [string] $NodeId, 
        [string] $PullServer
    )  
      
    LocalConfigurationManager

Get-Disk | Where { $_.PartitionStyle -eq "RAW" } | Initialize-Disk -PartitionStyle MBR 
Get-Disk | Where { $_.NumberOfPartitions -eq 0 } |   
    New-Partition -AssignDriveLetter -UseMaximumSize |
    Format-Volume -FileSystem NTFS -Force -Confirm:$false

ConfigureDSCPullServer -NodeId $guid -PullServer $pull_server
$guid | Add-Content -Encoding Ascii -Path ( Join-Path -Path "C:" -ChildPath $guid ) 