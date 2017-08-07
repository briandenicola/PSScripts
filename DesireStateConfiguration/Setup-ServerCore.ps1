#requires -version 4

<#
.SYNOPSIS
This PowerShell Script will setup a blank using via PowerShell DSC. 

.DESCRIPTION
Version - 1.0.0

This PowerShell Script will setup a blank using via PowerShell Workflows and DSC. The Script will do the following
*Rename the Computer
*Enable RDP
*Set TimeZone to Central Time Zone
*Disable UAC
*Moves CD-ROM drive to Z: drive
*Format and Mounts all Drives

.EXAMPLE
Setup-NewComputer-Workflow.ps1 -NewComputerName "server-1" 

.PARAMETER NewComputerName
Specifies the new name of the computer. Mandatory parameter

.NOTES
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)] [string] $NewComputerName
)

Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false

Install-Module -Name xComputerManagement -Confirm:$false -Force
Install-Module -Name xWindowsUpdate -Confirm:$false -Force
Install-Module -Name xCredSSP -Confirm:$false -Force
Install-Module -Name xTimeZone -Confirm:$false -Force
Install-Module -Name xRemoteDesktopAdmin -Confirm:$false -Force
Install-Module -Name xNetworking -Confirm:$false -Force
Install-Module -Name xSystemSecurity -Confirm:$false -Force

function Get-NextDriveLetter {
    param ([string] $current_drive )
    return ( [char][byte]([byte][char]$current_drive - 1) )
}

Set-Variable -Name new_drive_letter -Value "Z"
Set-Variable -Name cdrom_drives -Value @(Get-Volume | Where DriveType -eq "CD-ROM")

foreach( $drive in $cdrom_drives ) {
    $cd_drive = Get-WmiObject Win32_Volume | Where DriveLetter -imatch $drive.DriveLetter
    $cd_drive.DriveLetter = "$new_drive_letter`:"
    $cd_drive.put()
    $new_drive_letter = Get-NextDriveLetter -current_drive $new_drive_letter
}

Get-Disk | Where { $_.PartitionStyle -eq "RAW" } | Initialize-Disk -PartitionStyle MBR 
Get-Disk | Where { $_.NumberOfPartitions -eq 0 } |   
    New-Partition -AssignDriveLetter -UseMaximumSize |
    Format-Volume -FileSystem NTFS -Force -Confirm:$false

. (Join-Path -Path $PWD.Path -ChildPath "Modules\SetupNewCoreComputer.ps1") -NewComputerName $NewComputerName 
$mofPath = Join-Path -Path $ENV:TEMP -ChildPath "MOF"
Setup-NewComputer -OutputPath $mofPath
Start-DscConfiguration -Wait -Force -Verbose -Path $mofPath