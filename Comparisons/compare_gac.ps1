param (
	[string] $ref,
	[string] $dif
)	

. ..\Libraries\Standard_functions.ps1

$rGac = get-SystemGAC -server $ref
$dGac = get-SystemGAC -server $dif

Compare-Object $rGac $dGac -SyncWindow $rGac.Length -Property DllName,PublicKeyToken,Version
