[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[string] $dir = "",
	[string] $ext = "*.*",
	[string] $log = "D:\Scripts\Housekeeping\housekeeping.log",
	[string] $Comparison = "LastWriteTime",
	[int] $days=30,
	[switch] $archive,
	[string] $ArchiveDir,
	[switch] $help=$false
)

[void] [System.Reflection.Assembly]::LoadFrom((join-path $PWD.Path "ICSharpCode.SharpZipLib.dll"))
function Create-Zip 
{
	param(
		[string] $file
	)
	
	$zip = [ICSharpCode.SharpZipLib.Zip.ZipFile]::Create($file + ".zip")
	$zip.BeginUpdate()
	$zip.Add($file)
	$zip.CommitUpdate()
	$zip.Close()

}

if( $help -or $dir -eq "" ) 
{
	Write-Host "housekeeping.ps1 -dir <Directory to Clean Up> [OPTION] ..."
	Write-Host "`t-ext 	- Extension to include in the cleanup. Default: *.*"
	Write-Host "`t-log 	- Log file for results. Default: D:\Scripts\Housekeeping\housekeeping.log "
	Write-Host "`t-Comparison - What time stamp do you wish to compare. LastAccessTime or LastWriteTime. Default: LastWriteTime"
	Write-Host "`t-days	- Days to keep online. Default: 30"
	Write-Host "`t-archive - Switch to zip files and move the files to an Archive Directory"
	Write-Host "`t-ArchiveDir -  Directory to move files to"
	Write-Host "`t-help"
	exit
}

$now = Get-Date
$dPurgeDate = $now.AddDays(-$days)

dir $dir -Recurse | where { $_.$Comparison -lt $dPurgeDate -and $_.Extension -like $ext } | ForEach-Object {
	
	if($archive -and -not [String]::IsNullOrEmpty($ArchiveDir) )
	{
		"[" + $now.ToString() + "] - Archiving: " + $_.Fullname  | Out-File $log -Append -Encoding ASCII
		Create-Zip $_.FullName
		Move-Item ($_.FullName + ".zip") $ArchiveDir -Verbose
	}
	
	"[" + $now.ToString() + "] - Delete: " + $_.Fullname  | Out-File $log -Append -Encoding ASCII
	Remove-Item $_.FullName -Verbose 
}
