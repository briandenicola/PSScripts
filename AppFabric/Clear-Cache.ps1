#requires -version 2.0
[CmdletBinding()]

param (
    [ParaMeter(Mandatory=$true)][string] $cache,
    [ParaMeter(Mandatory=$true)][string] $server,
    [ParaMeter(Mandatory=$true)][int] $port = 22233
)

Import-Module DistributedCacheAdministration
Use-CacheCluster

Set-Variable -Name assembly_path -Value 'C:\Program Files\AppFabric 1.1 for Windows Server\Microsoft.ApplicationServer.Caching.Client.dll' -Option constant 
[Reflection.Assembly]::LoadFrom($assembly_path) | Out-Null

$end_points = New-Object -TypeName "Microsoft.ApplicationServer.Caching.DataCacheServerEndpoint" -ArgumentList $server, $port
$config = New-Object -TypeName "Microsoft.ApplicationServer.Caching.DataCacheFactoryConfiguration"
$config.Servers = [Microsoft.ApplicationServer.Caching.DataCacheServerEndpoint[]]($end_points)
 
$factory = New-Object -TypeName "Microsoft.ApplicationServer.Caching.DataCacheFactory" -ArgumentList $config
$data_cache = $factory.GetCache($cache)

foreach  ( $region in $data_cache.GetSystemRegions() )  {
    $data_cache.ClearRegion($region)
}
