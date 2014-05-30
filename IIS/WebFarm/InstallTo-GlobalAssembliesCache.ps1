[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[string] $directory,
    [string] $log
)

[System.Reflection.Assembly]::Load("System.EnterpriseServices, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a") | Out-Null

. (Join-Path $ENV:SCRIPTS_HOME "Libraries\Standard_Functions.ps1")

$assemblies = @()
function main()
{
	$publish = New-Object System.EnterpriseServices.Internal.Publish

	foreach( $file in (Get-ChildItem $directory -include *.dll -recurse) ) 
	{
        try { 
            $assembly = $file.FullName
            Write-Verbose "Installing: $assembly"
            
            $publish.GacInstall( $assembly )
            
            $assemblies += (New-Object PSObject -Property @{
              Name = $file.Name
              Assembly = $assembly
		      Hash = get-hash1 $assembly
              LastWriteTime = $file.LastWriteTime
              Version =  $file.VersionInfo.ProductVersion
            })
            
        }                                                                  
        catch { 
            "The assembly '$assembly' must be strongly signed."
        }
	}
    
    $assemblies | Export-CSV -NoTypeInformation -Encoding Ascii $log                                                   
    return $assemblies
}
main