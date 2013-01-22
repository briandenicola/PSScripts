param (
	[Parameter(Mandatory=$true)]
	[string] 
	$site,

	[Parameter(Mandatory=$true)]
	[string]
	$doclib,

	[string]
	$filter = [String]::Emtpy
)
	

if( $Host.Version.Major -ne 2 ) 
{
	Write-Host "This script requires PowerShell 2.0 to function" -Fore Red
	return
}

Add-PSSnapIn StoragePoint.PowershellCmdlets -ErrorAction SilentlyContinue

if( $filter -eq [String]::Empty ) {
	$query = "<OrderBy><FieldRef Name=`"Title`" Ascending=`"True`" /></OrderBy>"
}
else { 
	$query = "<Where><Contains><FieldRef Name=FileLeafRef /><Value Type=File>$filter</Value></Contains></Where>"
}

$storage_point_files = @()
foreach( $file in (Get-AllBLOBs -s $site -l $doclib -q $query) )
{
	$tmp = $file.DocUrl.Split("/")
	$file_name = $tmp[$tmp.Length-1].Replace("%20"," ")

	$storage_point_files += (New-Object PSObject -Property @{
		FileName = $file_name
		DocUrl = $file.DocUrl
		DocId = $file.DocId
		NASFolder = $file.Folder
		NASFileName = $file.Filename
	})
	
} 

return $storage_point_files
 