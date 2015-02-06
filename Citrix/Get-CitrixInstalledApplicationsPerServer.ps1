param(
	[string] $file
)
 
Add-PSSnapIn Citrix.Common.Commands -EA SilentlyContinue
Add-PSSnapin Citrix.XenApp.Commands -EA SilentlyContinue

foreach ( $server in Get-XAServer ) 
{
	$apps += Get-XAApplication -ServerName $server | Select DisplayName, @{Name="Server";Expression={$server}}, ApplicationType, CommandLineExecutable		
}

$apps = $apps | Sort DisplayName
if( -not [String]::IsNullOrEmpty($file) )
{

	$apps | Export-csv -Encoding ascii -NoTypeInformation $file
}
$apps