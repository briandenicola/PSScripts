<#
.SYNOPSIS
This PowerShell Script will synchronize two directories.  It can copy files from one directory or another.

.DESCRIPTION
Version - 1.0.0
The script recurse through a OneDrive directory looking for files not correctly synced locally. It will make a back a backup of the file and rename it to
kick OneDrive into syncing the file again.

.EXAMPLE
.\Fix-OneDriveSync.ps1 -Path "D:\OneDrive\Pictures\" -OutputPath \\nas\photo\Backups -Whatif

.EXAMPLE
.\Fix-OneDriveSync.ps1 -Path "D:\OneDrive\Pictures\" -OutputPath \\nas\photo\Backups -Filter "*.png"

.EXAMPLE
.\Fix-OneDriveSync.ps1 -Path "D:\OneDrive\Pictures\" -OutputPath \\nas\photo\Backups -StatusOnly

.PARAMETER Path
Specifies the main directory check for stuck files

.PARAMETER OutputPath
Specifies the directory to make a backup copy of the stuck files

.PARAMETER Filter
Filter to only certain files. Default is "*.jpg"

.PARAMETER StatusOnly
Returns an array of all files currently stuck syncing

.NOTES
This script requires the OneDriveLib library that can be downloaded from https://github.com/rodneyviana/ODSyncService

#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [string] $Path,
    [string] $OutputPath,
    [string] $Filter = "*.jpg",
    [switch] $StatusOnly
)

$OneDriveLib = "D:\Utils\OneDriveLib.dll"

Import-Module -Name $OneDriveLib

$badFiles = @()
foreach ( $item in (Get-ChildItem -Path $Path -Recurse -Include $Filter) ) {
    Write-Verbose -Message ("Working on {0}" -f $item.FullName)
    $status = Get-ODStatus -ByPath $item.FullName
    if( $status -ne "UpToDate" ) {
        Write-Verbose -Message ("{0} is not corrected synced with a status of {1}" -f $item.FullName, $status)
        if($StatusOnly) {
            $badFiles += (New-Object -TypeName psobject -Property @{
                FullName = $item.FullName
                Status   = $status
            })
        } else {
            $Target = Join-Path -Path $item.Directory.FullName -ChildPath ("{0}-fixed{1}" -f $item.BaseName, $item.Extension )

            if($PSCmdlet.ShouldProcess($Target, "Fixing OneDrive File")){
                Copy-Item -Path $item.FullName -Destination $Target
                Move-Item -Path $item.FullName -Destination $OutputPath
            } else {
                Copy-Item -Path $item.FullName -Destination $Target -Verbose
                Move-Item -Path $item.FullName -Destination $OutputPath -Verbose
            } 
        }
    }
}

if($StatusOnly) {
    return $badFiles
}