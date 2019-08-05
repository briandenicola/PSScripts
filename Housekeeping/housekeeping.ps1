<#
.SYNOPSIS
This PowerShell Script will purge a directory of old files.  It can copy a zipped archvie to another folder for preservation.

.DESCRIPTION
Version - 1.5.0
This version is designed to handled directories with large number of files (>10,000)
Version - 1.0.0
This PowerShell Script will purge a directory of old files.  It can copy a zipped archvie to another folder for preservation.

.EXAMPLE
.\housekeeping.ps1 -Dir c:\SourceFolder

.EXAMPLE
.\housekeeping.ps1 -Dir c:\SourceFolder -Ext "*.log" -Days 2  

.PARAMETER Directory
Directory to Clean Up. Mandatory parameter

.PARAMETER ext
Extension to include in the cleanup. Default: *.*

.PARAMETER Comparison
What time stamp do you wish to compare. LastAccessTime or LastWriteTime. Default: LastWriteTime

.PARAMETER Days
Days to keep online. Default: 30

.PARAMETER log
Full Path to Log file. Parameter

.PARAMETER Archive
Switch to zip files and move the files to an Archive Directory

.PARAMETER ArchiveDirectory
Directory to Zip and Move files to

.NOTES

#>
[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[Parameter(Mandatory=$true)]
	[Alias('dir')]
	[ValidateScript({Test-Path $_ -PathType 'Container'})] 
	[string] $Directory,

	[Parameter(Mandatory=$false)]
	[Alias('ext')]
	[string] $Extension = "*.*",

	[Parameter(Mandatory=$false)]
	[ValidateSet("LastWriteTime","LastAccessTime")] 
	[string] $Comparison = "LastWriteTime",

	[Parameter(Mandatory=$false)]
	[ValidateRange(0,365)]
	[int] $Days = 30,

	[Parameter(Mandatory=$false)]
	[switch] $Archive,

	[Parameter(Mandatory=$false)]
	[Alias('Archivedir')]
	[string] $ArchiveDirectory = ( Join-Path -Path $PWD.Path -ChildPath "Archive" ),

	[Parameter(Mandatory=$false)]
	[string] $log = ( Join-Path -Path $PWD.Path -ChildPath "housekeeping.log")
)

[void] [System.Reflection.Assembly]::LoadFrom((Join-Path -Path $PWD.Path -ChildPath "ICSharpCode.SharpZipLib.dll"))
function Create-Zip 
{
	param(
		[string] $Source,
		[string] $ZipFile
	)

	$zip = [ICSharpCode.SharpZipLib.Zip.ZipFile]::Create($ZipFile)
	$zip.BeginUpdate()
	$zip.Add($Source)
	$zip.CommitUpdate()
	$zip.Close()
}

$now = Get-Date
$PurgeDate = $now.AddDays(-$days)

if($Archive){	
	$ArchiveDirectory = Join-Path -Path $ArchiveDirectory -ChildPath $now.ToString("yyyy-MM-dd")
	New-Item -ItemType Directory -Value $ArchiveDirectory -ErrorAction SilentlyContinue | Out-Null
}

Write-Verbose -Message ("[{0}] - Parsing {1} . . ." -f $(Get-Date), $Directory)
$files_to_purge = Get-ChildItem -Path $Directory -Recurse | Where { $_.PSIsContainer -eq $false }
 
foreach( $file_to_purge in $files_to_purge ) {
	Write-Verbose -Message ("[{0}] - Working on {1}. {2} is {3} . . ." -f $(Get-Date), $file_to_purge.FullName, $Comparison, $file_to_purge.$Comparison  )

	if( $file_to_purge.$Comparison -lt $PurgeDate -and $file_to_purge.Extension -like $Extension ) {
		if($Archive){
			$archive_name = Join-Path -Path $ArchiveDirectory -ChildPath ("{0}-{1}.zip" -f $file_to_purge.Directory.Name, $file_to_purge.BaseName)
			Out-File $log -Append -Encoding ASCII -InputObject ("[{0}] - Archiving: {1} to {2}" -f $(Get-Date), $file_to_purge.Fullname, $archive_name )
			Create-Zip -Source $file_to_purge.FullName -ZipFile $archive_name
		}
		Out-File $log -Append -Encoding ASCII -InputObject ("[{0}] - Delete: {1}" -f $(Get-Date), $file_to_purge.Fullname )
		Remove-Item -Path $file_to_purge.FullName -Verbose -ErrorAction SilentlyContinue
	} 
}