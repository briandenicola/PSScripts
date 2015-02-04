[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[string] $dir,
	[string] $log_home = "D:\Logs"
)


[System.Reflection.Assembly]::Load("System.EnterpriseServices, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a") | Out-Null

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")

$gac_out_file = Join-Path -Path $log_home -ChildPath "gac_install_record.log"

function main()
{
	$publish = New-Object System.EnterpriseServices.Internal.Publish

	foreach( $file in (Get-ChildItem $dir -include *.dll -recurse) ) 
	{
		$assembly = $file.FullName
		$fileHash = get-hash1 $assembly
		
		Write-Verbose "Installing: $assembly"
		  
		if ( [System.Reflection.Assembly]::LoadFile( $assembly ).GetName().GetPublicKey().Length -eq 0 )
		{
		  throw "The assembly '$assembly' must be strongly signed."
		}
		
		"{0},{1},{2},{3},{4}" -f $(Get-Date), $file.Name, $file.LastWriteTime, $file.VersionInfo.ProductVersion, $fileHash | out-file -append -encoding ascii $gac_out_file    
		$publish.GacInstall( $assembly )
	}
}
main