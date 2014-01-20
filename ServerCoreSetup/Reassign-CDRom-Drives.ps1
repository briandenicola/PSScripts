#requires -version 4

[CmdletBinding(SupportsShouldProcess=$true)]
param()

if( [Environment]::OSVersion.Version -ne (new-object 'Version' 6,2) ) {
    throw "This script needs to run on Windows 2012 or greater"
}

Set-Variable -Name cdrom_drives -Value @(Get-Volume | Where DriveType -eq "CD-ROM")
Set-Variable -Name new_drive_letter -Value "Z"

function Get-NextDriveLetter
{
    param (
        [string] $current_drive
    )
    return ( [char][byte]([byte][char]$current_drive - 1) )
}


foreach( $drive in $cdrom_drives ) {
    Write-Host ("Moving {0} to {1} . . ." -f $drive.DriveLetter, $new_drive_letter
    Set-Partition -DriveLetter $drive.DriveLetter -NewDriveLetter $new_drive_letter -Verbose
    $new_drive_letter = Get-NextDriveLetter -current_drive $new_drive_letter
}