[CmdletBinding()]
param ( 
    [Parameter(Mandatory=$true)] 
	[string] $VPNConnectionName,

    [Parameter(Mandatory=$true, HelpMessage='Enter a valid Destination Prefix in the format `"w.x.y.z/a`"')] 
    [ValidatePattern("^(?:[0-9]{1,3}\.){3}[0-9]{1,3}\/[0-9]{1,2}$")]
	[string] $RemoteNetworkPrefix
)

rasdial.exe $VPNConnectionName

$ip = Get-NetIPAddress -InterfaceAlias $VPNConnectionName | Select -ExpandProperty IPAddress
#Get-NetRoute | where DestinationPrefix -eq $RemoteNetworkPrefix | Remove-NetRoute -Confirm:$false
route delete ($RemoteNetworkPrefix.Split("/")[0])
New-NetRoute -DestinationPrefix $RemoteNetworkPrefix -NextHop $ip -InterfaceAlias $VPNConnectionName